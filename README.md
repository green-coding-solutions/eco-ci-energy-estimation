# Eco-CI

Eco-CI is a project aimed at estimating energy consumption in continuous integration (CI) environments. It provides functionality to calculate the energy consumption of CI jobs based on the power consumption characteristics of the underlying hardware.


## Table of Contents
- [Requirements / Dependencies](#requirements--dependencies)
- [How Does It Work?](#how-does-it-work)
- [Usage](#usage)
  - [GitHub](#github)
    - [GitHub Action Mandatory and Optional Variables](#github-action-mandatory-and-optional-variables)
    - [Electricity Maps Token](#electricity-maps-token)
    - [Continuing on Errors](#continuing-on-errors)
    - [Consuming the Measurements as JSON](#consuming-the-measurements-as-json)
    - [Note on Private Repos](#note-on-private-repos)
    - [Support for Dedicated Runners / Non-Standard Machines](#support-for-dedicated-runners--non-standard-machines)
  - [GitLab](#gitlab)
    - [Artifacts for GitLab](#artifacts-for-gitlab)
    - [GitLab Sample File](#gitlab-sample-file)
  - [macOS](#macos)
  - [Local CI / Running in Docker](#local-ci--running-in-docker)
    - [Trying out with Docker and Circle-CI image](#trying-out-with-docker-and-circle-ci-image)
    - [Trying out with Docker and KDE pipelines](#trying-out-with-docker-and-kde-pipelines)
  - [Jenkins](#jenkins)
- [Note on the integration / Auto-Updates](#note-on-the-integration-auto-updates)
- [Limitations / Compatibility](#limitations--compatibility)

## Requirements / Dependencies
Following packages are expected:
- `curl`
- `jq`
- `awk`
- `date` with microsecond support. On *alpine* and *macOS* this means installing `coreutils`
- `bash` > 4.0
- `git` only if you use GitLab

## How does it work?
- The Eco-CI at its core makes its energy estimations based on pre-calculated power curves from [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy)
- When you initialize the Eco-CI, starts a small bash script to track the cpu utilization over a period of time. This tracking begins when you call the start-measurement function. Then, each time you call get-measurement, it will take the cpu-utilization data collected (either from the start, or since the last get-measurement call) and make an energy estimation based on the detected hardware and CPU utilization.

## Usage

Eco-CI supports both GitHub and GitLab as CI platforms. When you integrate it into your pipeline, you must call the start-measurement script to begin collecting power consumption data, then call the get-measurement script each time you wish to make a spot measurement. When you call get-measurment, you can also assign a label to it to more easily identify the measurement. At the end, call the display-results to see all the measurement results, overall total usage, and export the data.

Follow the instructions below to integrate Eco-CI into your CI pipeline.

### GitHub:
To use Eco-CI in your GitHub workflow, call it with the relevant task name (start-measurement, get-measurement, or display-results). Here is a sample workflow that runs some python tests with eco-ci integrated.

```yaml
name: Daily Tests with Energy Measurement
run-name: Scheduled - DEV Branch
on:
  schedule:
    - cron: '0 0 * * *'

permissions:
  read-all

jobs:
  run-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Start Measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v4 # use hash or @vX here (See note below)
        with:
          task: start-measurement
        # continue-on-error: true # recommended setting for production. See notes below.


      - name: 'Checkout repository'
        uses: actions/checkout@v4
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v4 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'repo checkout'
        # continue-on-error: true # recommended setting for production. See notes below.

      - name: setup python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'
          cache: 'pip'

      - name: pip install
        shell: bash
        run: |
          pip install -r requirements.txt

      - name: Setup Python Measurment
        uses: green-coding-solutions/eco-ci-energy-estimation@v4 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'python setup'
        # continue-on-error: true # recommended setting for production. See notes below.

      - name: Run Tests
        shell: bash
        run: |
          pytest

      - name: Tests measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v4 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'pytest'
        # continue-on-error: true # recommended setting for production. See notes below.

      - name: Show Energy Results
        uses: green-coding-solutions/eco-ci-energy-estimation@v4 # use hash or @vX here (See note below)
        with:
          task: display-results
        # continue-on-error: true # recommended setting for production. See notes below.

```

#### GitHub Action Mandatory and Optional Variables:

- `task`: (required) (options are `start-measurement`, `get-measurement`, `display-results`)
    + `start-measurement`: Initialize the action and starts the measurement. This must be called, and only *once* per job. If called again data will be reset.
        - `branch`: (optional) (default: ${{ github.ref_name }})
          - Used to correctly identify this CI run for the Badge. Especially in PRs this will be very cryptic like `merge/72` and you might want to set this to something nicer
        - `label`: (optional) (default: 'measurement ##')
        - `send-data`: (optional) (default: true)
          - Send metrics data to metrics.green-coding.io to create and display badge, and see an overview of the energy of your CI runs. Set to false to send no data. The data we send are: the energy value and duration of measurement; cpu model; repository name/branch/workflow_id/run_id; commit_hash; source (GitHub or GitLab). We use this data to display in our green-metrics-tool front-end here: https://metrics.green-coding.io/ci-index.html
        - `calculate-co2`: (optional) (default: true)
          - You might typically always want this value to be shown unless you are in a restricted network and cannot make outbound requests 
          - Gets the location using https://ipapi.co/
          - Get the CO2 grid intensity for the location from https://www.electricitymaps.com/
          - Estimates the amount of carbon the measurement has produced
        - `gh-api-base`: (optional) (default: 'api.github.com')
            - Eco-CI uses the github api to post/edit PR comments and get the workflow id
            - set to github's default api, but can be changed if you are using github enterprise
        - `type`: (optional)
            - If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set a type for drill-down later. Defaults to "machine.ci". Cannot be empty.[CarbonDB](https://www.green-coding.io/projects/carbondb/)
        - `project`: (optional)
            - If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set a type for drill-down later. Defaults to "CI/CD". Cannot be empty.[CarbonDB](https://www.green-coding.io/projects/carbondb/)
        - `machine`: (optional)
            - If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set a type for drill-down later. Defaults to "ubuntu-latest". Cannot be empty.[CarbonDB](https://www.green-coding.io/projects/carbondb/)
        - `tags`: (optional)
            - If you want filter data in the GMT Dashboard or in CarbonDB you can here manually set tags for drill-down later. Please supply comma separated. Tags cannot have commas itself or contain quotes. Defaults to empty.[CarbonDB](https://www.green-coding.io/projects/carbondb/)
        - `gmt-api-token`: (optional)
            - If you are not using the default user for the GMT API supply your auth token. We recommend to have this as a GitHub Secret.
        - `api-endpoint-add`: (optional)
            - When using the GMT Dashboard and / or CarbonDB specify the endpoint URL to send to. Defaults to "https://api.green-coding.io/v2/ci/measurement/add"
        - `api-endpoint-badge-get`: (optional)
            - When using the GMT Dashboard and / or CarbonDB specify the endpoint URL to get the badge from to. Defaults to "https://api.green-coding.io//v1/ci/badge/get
        - `electricitymaps-api-token`: (optional)
            - API token for electricitymaps in case you get rate-limited. See details below.
- `get-measurement`: Measures the energy at this point in time since either the start-measurement or last get-measurement action call.
    - `label`: (optional) (default: 'measurement ##')

- `display-results`: Outputs the energy results to the`$GITHUB_STEP_SUMMARY`. Creates a table that shows the energy results of all the `get-measurements`, and then a final row for the entire run. Displays the average cpu utilization, the total Joules used, and average wattage for each measurement+total run. This badge will always be updated to display the total energy of the most recent run of the workflow that generated this badge. The total measurement of this task is provided as output `data-total-json` in json format (see example below).
    - `pr-comment`: (optional) (default: false)
        - if on, will post a comment on the PR issue with the Eco-CI results. only occurs if the triggering event is a pull_request
        - remember to set `pull-requests: write` to true in your workflow file
    - `display-table`: (optional) (default: true)
    - `display-badge`: (optional) (default: true)
        - used with display-results
        - Shows the badge for the ci run during display-results step
        - automatically false if `send-data is also false
    - `json-output`: (optional) (default: false)
        - will output data to JSON to `/tmp/eco-ci/lap-data.json` and `/tmp/eco-ci/total-data.json`

#### Electricity Maps Token

We use https://app.electricitymaps.com/ to get the grid intensity for a given location. This service currently works without specifying a token but we recommend to still get one under https://api-portal.electricitymaps.com/

You will need to set this token as a secret and pass it in the initalization. To learn how to create a secret see the GitHub documentation: https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions

You will then need to pass it in your workflow files in the initialization. See documentation above.

#### Continuing on Errors

Once you have initially set up Eco-CI and have given it a test spin we recommend running our action 
with `continue-on-error:true`, as energy and CO2 metrics is not critical to the success of your workflow, but rather a nice feature to have.

```yaml
      - name: Eco CI Energy Estimation
        uses: green-coding-solutions/eco-ci-energy-estimation@v4
        with:
          task: final-measurement
        continue-on-error: true
```

#### Consuming the Measurements as JSON

For both tasks `get-measurement` and `display-results` the lap measurements and total measurement can be consumed in JSON format.
You can use the outputs `data-lap-json` or `data-total-json` respectively.

You must set `json-output` to true in GitHub or `export ECO_CI_JSON_OUTPUT="true"` for it to be active.

Here is an example demonstrating how this can be achieved:

```yaml
      # ...
      - name: 'Checkout repository'
        uses: actions/checkout@v4
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurment
        uses: green-coding-solutions/eco-ci-energy-estimation@v4
        id: checkout-step
        with:
          task: get-measurement
          label: 'repo checkout'

      - name: Print checkout data
        run: |
          echo "total json: ${{ steps.checkout-step.outputs.data-lap-json }}"

      - name: Show Energy Results
        uses: green-coding-solutions/eco-ci-energy-estimation@v4
        id: total-measurement-step
        with:
          task: display-results

      - name: Print total data
        run: |
          echo "total json: ${{ steps.total-measurement-step.outputs.data-total-json }}"
```

Note that the steps you want to consume the measurements of need to have an `id` so that you can access the corresponding data from their outputs.

#### Note on private repos
 If you are running in a private repo, you must give your job actions `read` permissions for the GITHUB_TOKEN. This  is because we make an api call to get your workflow_id which uses your `$GITHUB_TOKEN`, and it needs the correct permissions to do so:
 ```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      actions: read
    steps:
      - name: Eco CI - Start Measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v4
        with:
          task: start-measurement
 ```

#### Support for dedicated runners / non-standard machines

This plugin is primarily designed for the [GitHub Shared Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners/about-github-hosted-runners#supported-runners-and-hardware-resources) and comes with their energy values already pre-calculated.

All the values for supported machines are found in the [power-data](https://github.com/green-coding-solutions/eco-ci-energy-estimation/tree/main/power-data) folder.

The heavy work to get this values is done by [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy) (See below for details).

If you want to support a custom machine you need to create one of these files and load it into Eco-CI.

Here is an exemplary command to create the power data for the basic **4 CPU** GitHub Shared Runner (at the time of writing 13. June 2024).

`python3 xgb.py --tdp 280 --cpu-threads 128 --cpu-cores=64 --cpu-make "amd" --release-year=2021 --ram 512 --cpu-freq=2450 --cpu-chips=1 --vhost-ratio=0.03125 --dump-hashmap > github_EPYC_7763_4_CPU_shared.sh`

The following would be the command for [Gitlab Shared Runners](https://docs.gitlab.com/ee/ci/runners/hosted_runners/linux.html) (at the time of writing 13. June 2024)

`python3 xgb.py --tdp 240 --cpu-threads 128 --cpu-cores=64 --cpu-make "amd" --release-year=2021 --ram 512 --cpu-freq=2250 --cpu-chips=1 --vhost-ratio=0.015625 --dump-hashmap > gitlab_EPYC_7B12_saas-linux-small-amd64.txt`

Gitlab uses an AMD EPYC 7B12 according to [our findings](https://www.green-coding.io/case-studies/cpu-utilization-usefulness/)


You can see how the machine specs must be supplied to [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy) and also, since the runners are shared, you need to supply the splitting ratio that is used.

Since GitHub for instance uses an `AMD EPYC 7763`, which only comes with 64 cores and 128 threads, and gives you **4 CPUs** the assumption is 
that the splitting factor is `4/128 = 0.03125`. 

An uncertainty is if Hyper-Threading / SMT is turned on or off, but we believe it is reasonable to assume that for Shared runners they will turn it on as it generally increases
throughput and performance in shared environments.

If you have trouble finding out the splitting factor for your system: [Open an issue!](https://github.com/green-coding-solutions/eco-ci-energy-estimation/issues) We are happy to help!!

Once you have the file ready we are happy to merge it in through a PR! In future versions we also plan to include a loading mechanism, where you can just
ingest a file from your repository without having to upstream it with us. But since this is a community open source plugin upstream is preferred, right :)

### GitLab
To use Eco-CI in your GitLab pipeline, you must first include a reference to the eco-ci-gitlab.yml file as such:
```
include:
  remote: 'https://raw.githubusercontent.com/green-coding-solutions/eco-ci-energy-estimation/main/eco-ci-gitlab.yml'
```

and you call the various scripts in your pipeline with call like this:
```
- !reference [.<function-name>, script]
```
where function name is one of the following:
`start_measurement` - begin the measurment
`get_measurement` - make a spot measurment here. If you wish to label the measurement, you need to set the ECO_CI_LABEL environment variable right before this call.
`display_results` - will print all the measurement values to the jobs-output and prepare the artifacts, which must be exported in the normal GitLab way.

By default, we send data to our API, which will allow us to present you with a badge, and a front-end display to review your results. The data we send are: the energy value and duration of measurement; cpu model; repository name/branch/workflow_id/run_id; commit_hash; source (GitHub or GitLab). We use this data to display in our green-metrics-tool front-end here: https://metrics.green-coding.io/ci-index.html

If you do not wish to send us data, you can set this global variable in your pipeline:

```
variables:
  ECO_CI_SEND_DATA: "false"
```


#### Artifacts for GitLab
For each job you can export the artifacts. We currently export the pipeline data as a regular artifact, as well as make use of GitLab's [Metric Report](https://docs.gitlab.com/ee/ci/testing/metrics_reports.html) artifact (which we output to the default metrics.txt):

```
artifacts:
    paths:
      - eco-ci-output.txt
      - eco-ci-total-data.json
    reports:
      metrics: metrics.txt
```

#### Gitlab sample file

Please look at [.gitlab-ci.yml.example](.gitlab-ci.yml.example)


### macOS

*macOS* requires the *GNU* `date` tool so it can properly create a microsecond timestamp.

Install it with the package manager of your choice and then add its binary first in the `PATH` variable, so that it precedes the *BSD* `date`.

Example for `homebrew`:
```bash
brew install coreutils
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
# then you can run:
bash local_ci.example.sh
```

### Local CI / Running in docker

Although initially designed for use in *GitHub Actions* and *GitLab Pipelines* the Eco-CI tool works everywhere where `bash` works.

This means you can just use it locally by following it's general 3-step interface:
- Start
- Measure (optionally repeat if you want to lap multiple steps)
- End & Display

As an example we have set up a full example pipeline in the form of a `bash` file under `local_ci.example.sh`.

In this file you find the needed calls along with some fake activity like calls to `sleep` and `ls` etc.

You just need to slice the file to you needs and bring the code that you want to encapsulate with Eco-CI into the positions where currently the `sleep` and `ls` calls are.



#### Trying out with Docker and Circle-CI image

For local testing you can just run in the docker container of your choice, directly from the root of the repository.

Here is an example with the Circle-CI base image:
```bash
docker run --network host --rm -it -v ./:/tmp/data:ro cimg/base:current bash /tmp/data/local_ci.example.sh
```

In case you are testing with a local installation of the GMT append `--network host` to access `api.green-coding.internal`


#### Trying out with Docker and KDE pipelines
```bash
docker run --rm -it -v ./:/tmp/data:ro invent-registry.kde.org/sysadmin/ci-images/suse-qt67:latest bash /tmp/data/local_ci.example.sh
```

### Jenkins

For *Jenkins* Eco-CI can be easily used in combination with the *Execute Shell* plugin.

By following Eco-CI's general 3-step you need to create 3 steps in your workflow that:
- Start
- Measure (optionally repeat if you want to lap multiple steps)
- End & Display

You need to have the `eco-ci-energy-estimation` repository checked out somewhere, where *Jenkins* can read it.

#### Example codeblocks

Replace `__PATH_WHERE_YOU_HAVE_THE_REPO__` with the actual repo location.

**Start**:
```bash
bash __PATH_WHERE_YOU_HAVE_THE_REPO__/scripts/examples/jenkins_start.sh
```

**Measure Step**:
You should set a custom text label for the step, here defined with the variable `LABEL`

```bash
LABEL="This is the step label"
bash __PATH_WHERE_YOU_HAVE_THE_REPO__/scripts/examples/jenkins_measure.sh "${LABEL}"
```


**End and display data**:
You should set a custom text label for the step, here defined with the variable `LABEL`

```bash
LABEL="This is the step label"
bash __PATH_WHERE_YOU_HAVE_THE_REPO__/scripts/examples/jenkins_end_and_display.sh "${LABEL}"
```

See a full example of a freestyle pipeline with the codeblocks here: ![Screenshot Jenkins Freestyle pipeline](/screenshots/jenkins_eco_ci_integration_freestyle_pipeline.png)

The data will then show up in the text log. See an example how this looks here: ![Screenshot Jenkins Eco-CI Output](/screenshots/jenkins_eco_ci_output.png)

#### Jenkins on macOS

If you use *Jenkins* on *macOS* you must have `coretuils` installed and `gdate` must replace the normal `date` function.

Append this to every step where you call Eco-CI precede the linux `date` tool before the *macOS* native one:
```bash
set +x # if macOS to reduce noise
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH" # if macOS
```

## Note on the integration / Auto-Updates
- If you want the extension to automatically update within a version number, use the convenient @vX form. 
  + `uses: green-coding-solutions/eco-ci-energy-estimation@v4 # will pick the latest minor v4.x`
  + In case of a major change from @v4 to @v5 you need to upgrade manually. The upside is: If you use dependabot it will create a PR for you as it understands the notation
    
- If you want to pin the dependency and want to audit every release we recommend using the hash notation
  + `uses: green-coding-solutions/eco-ci-energy-estimation@06837b0b3b393a04d055979e1305852bda82f044 #resolves to v2.2`
  + Note that this hash is just an example. You find the latest current hash under [Tags](https://github.com/green-coding-solutions/eco-ci-energy-estimation/tags)
  + Dependabot also understands this notation so it will create an update with the changelog for you
- If you want the bleeding edge features use the @main notation.
  + `uses: green-coding-solutions/eco-ci-energy-estimation@main`
  + We do **not** recommend this as it might contain beta features. We recommend using the releases and tagged versions only


## Limitations / Compatibility
- At the moment this will only work with linux based pipelines, mainly tested on ubuntu images.
  + The plugin is tested on:
  + GitHub
      + `ubuntu-latest` (GitHub - 22.04 at the time of writing)
      + `ubuntu-24.04` (GitHub)
      + `ubuntu-20.04` (GitHub)
      + [Autoscaling Github Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/managing-larger-runners#configuring-autoscaling-for-larger-runners) are not supported
      + The plugin technically supports large runners, but they will need extra pre-calculated power curved. Contact us if you need them and we are happy to bring them in!
  + GitLab
      + `saas-linux-small-amd64` (GitLab)
  + Generic
      + `alpine` (Install dependencies before - See above)
  + *macOS* is working on our local test machines (see install details below). 
      + Runners on GitHub are untested, but should work. You need to create a power profile though (see Cloud Energy below). We are happy for beta testers! contact us :)
  + Windows is currently only supported with WSL2

- If you use Alpine, you must install coreutils so that time logging with date is possible with an accuracy of microseconds (`apk add coreutils`)

- If you have your pipelines split over multiple VM's (often the case with many jobs) ,you have to treat each VM as a seperate machine for the purposes of measuring and setting up Eco-CI.

- The underlying [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy) model requires the CPU to have a fixed frequency setting. This is typical for cloud testing and is the case for instance on GitHub, but not always the case in different CIs.

See also our [work on analysing fixed frequency in Cloud Providers and CI/CD](https://www.green-coding.io/case-studies/cpu-utilization-usefulness/)

- The Cloud Energy model data is trained via the [SPECpower](https://www.spec.org/power_ssj2008/results/) database, which was mostly collected on compute machines. Results will be off for non big cloud servers and also for machines that are memory heavy or machines which rely more heavily on their GPU's for computations.
