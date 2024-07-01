# Eco-CI

Eco-CI is a project aimed at estimating energy consumption in continuous integration (CI) environments. It provides functionality to calculate the energy consumption of CI jobs based on the power consumption characteristics of the underlying hardware. Repo is forked from https://github.com/green-coding-solutions.


## Requirements
Following packages are expected:
- `curl`
- `jq`
- `awk`

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
        uses: green-coding-solutions/eco-ci-energy-estimation@v3 # use hash or @vX here (See note below)
        with:
          task: start-measurement
        # continue-on-error: true # recommended setting for production. See notes below.


      - name: 'Checkout repository'
        uses: actions/checkout@v3
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v3 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'repo checkout'
        # continue-on-error: true # recommended setting for production. See notes below.

      - name: setup python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
          cache: 'pip'

      - name: pip install
        shell: bash
        run: |
          pip install -r requirements.txt

      - name: Setup Python Measurment
        uses: green-coding-solutions/eco-ci-energy-estimation@v3 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'python setup'
        # continue-on-error: true # recommended setting for production. See notes below.

      - name: Run Tests
        shell: bash
        run: |
          pytest

      - name: Tests measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v3 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'pytest'
        # continue-on-error: true # recommended setting for production. See notes below.

      - name: Show Energy Results
        uses: green-coding-solutions/eco-ci-energy-estimation@v3 # use hash or @vX here (See note below)
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
        - `company-uuid`: (optional)
            - If you want to add your CI/CD runs to the [CarbonDB](https://www.green-coding.io/projects/carbondb/) you can set your company uuid here. If you set this all your runs will be found for your company. Please note that if your CI is public your company uuid will be exposed and other people could check your CO2 footprint. We recommend setting these variables as GitHub secrets in this case.
            - Please note that we will add the label as a tag so you can see which steps generated how much CO2
        - `project-uuid`: (optional)
            - If you want to group your CI/CD runs by project
        - `machine-uuid`: (optional)
            - If you want to make the runs look like they all ran on the same machine. This is not recommended as it will not be accurate but can be helpful for debugging.
            - Leave this field empty if you want an auto-generated value


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

You will need to set this token as a secret `ELECTRICITY_MAPS_TOKEN`. See the documentation how to do this https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions

You will also need to set it in your workflow files where you call `display-results` and `get-measurement`:
```
  - name: Eco CI Energy Estimation
    uses: ./
    env:
      ELECTRICITY_MAPS_TOKEN: ${{ secrets.ELECTRICITY_MAPS_TOKEN }}
    with:
      task: display-results
      pr-comment: true

```

#### Continuing on Errors

Once you have initially set up Eco-CI and have given it a test spin we recommend running our action 
with `continue-on-error:true`, as energy and CO2 metrics is not critical to the success of your workflow, but rather a nice feature to have.

```yaml
      - name: Eco CI Energy Estimation
        uses: green-coding-solutions/eco-ci-energy-estimation@v3
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
        uses: actions/checkout@v3
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurment
        uses: green-coding-solutions/eco-ci-energy-estimation@v3
        id: checkout-step
        with:
          task: get-measurement
          label: 'repo checkout'

      - name: Print checkout data
        run: |
          echo "total json: ${{ steps.checkout-step.outputs.data-lap-json }}"

      - name: Show Energy Results
        uses: green-coding-solutions/eco-ci-energy-estimation@v3
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
        uses: green-coding-solutions/eco-ci-energy-estimation@v3
        with:
          task: start-measurement
 ```

### Support for dedicated runners / non-standard machines

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

If you have trouble finding out the splitting factor for your system: Open an issue! We are happy to help!!

Once you have the file ready we are happy to merge it in through a PR! In future versions we also plan to include a loading mechanism, where you can just
ingest a file from your repository without having to upstream it with us. But since this is a community open source plugin upstream is preferred, right :)

### GitLab:
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

Then, for each job you need to export the artifacts. We currently export the pipeline data as a regular artifact, as well as make use of GitLab's [Metric Report](https://docs.gitlab.com/ee/ci/testing/metrics_reports.html) artifact (which we output to the default metrics.txt):

```
artifacts:
    paths:
      - eco-ci-output.txt
      - eco-ci-total-data.json
    reports:
      metrics: metrics.txt
```

Here is a sample .gitlab-ci.yml example file to illustrate:

```
image: ubuntu:22.04
include:
  remote: 'https://raw.githubusercontent.com/green-coding-solutions/eco-ci-energy-estimation/main/eco-ci-gitlab.yml'

stages:
  - test

test-job:
  stage: test
  script:
    - !reference [.start_measurement, script]

    - sleep 10s # Your main pipeline logic here
    - export ECO_CI_LABEL="measurement 1"
    - !reference [.get_measurement, script]

    - sleep 3s # more of your pipeline logic here
    - export ECO_CI_LABEL="measurement 2"
    - !reference [.get_measurement, script]

    - !reference [.display_results, script]

  artifacts:
    paths:
      - eco-ci-output.txt
    reports:
      metrics: metrics.txt
  ```


### How does it work?
- The Eco-CI at its core makes its energy estimations based on pre-calculated power curves from [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy)
- When you initialize the Eco-CI, starts a small bash script to track the cpu utilization over a period of time. This tracking begins when you call the start-measurement function. Then, each time you call get-measurement, it will take the cpu-utilization data collected (either from the start, or since the last get-measurement call) and make an energy estimation based on the detected hardware and CPU utilization.

### Limitations / Compatibility
- At the moment this will only work with linux based pipelines, mainly tested on ubuntu images.
  + The plugin is tested on:
  + `ubuntu-latest` (22.04 at the time of writing)
  + `ubuntu-24.04`
  + `ubuntu-20.04`
  + [Autoscaling Github Runners](https://docs.github.com/en/actions/using-github-hosted-runners/about-larger-runners/managing-larger-runners#configuring-autoscaling-for-larger-runners) are not supported 
  + Also Windows and macOS are currently not supported.
  + The plugin technically supports large runners, but they will need extra pre-calculated power curved. Contact us if you need them and we are happy to bring them in!

- If you have your pipelines split over multiple VM's (often the case with many jobs) ,you have to treat each VM as a seperate machine for the purposes of measuring and setting up Eco-CI.

- The underlying [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy) model requires the CPU to have a fixed frequency setting. This is typical for cloud testing and is the case for instance on GitHub, but not always the case in different CIs.

See also our [work on analysing fixed frequency in Cloud Providers and CI/CD](https://www.green-coding.io/case-studies/cpu-utilization-usefulness/)

- The Cloud Energy model data is trained via the [SPECpower](https://www.spec.org/power_ssj2008/results/) database, which was mostly collected on compute machines. Results will be off for non big cloud servers and also for machines that are memory heavy or machines which rely more heavily on their GPU's for computations.

### Note on the integration / Auto-Updates
- If you want the extension to automatically update within a version number, use the convenient @vX form. 
  + `uses: green-coding-solutions/eco-ci-energy-estimation@v3 # will pick the latest minor v3.x`
  + In case of a major change from @v3 to @v4 you need to upgrade manually. The upside is: If you use dependabot it will create a PR for you as it understands the notation
    
- If you want to pin the dependency and want to audit every release we recommend using the hash notation
  + `uses: green-coding-solutions/eco-ci-energy-estimation@06837b0b3b393a04d055979e1305852bda82f044 #resolves to v2.2`
  + Note that this hash is just an example. You find the latest current hash under [Tags](https://github.com/green-coding-solutions/eco-ci-energy-estimation/tags)
  + Dependabot also understands this notation so it will create an update with the changelog for you
- If you want the bleeding edge features use the @main notation.
  + `uses: green-coding-solutions/eco-ci-energy-estimation@main`
  + We do **not** recommend this as it might contain beta features. We recommend using the releases and tagged versions only


### Testing

For local testing you can just run in the docker container of your choice, directly from the root of the repository:
```bash
docker run --rm -it -v ./:/tmp/data:ro invent-registry.kde.org/sysadmin/ci-images/suse-qt67:latest bash /tmp/data/local_ci.example.sh
```
