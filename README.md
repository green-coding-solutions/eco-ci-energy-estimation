# Eco-CI

Eco-CI is a project aimed at estimating energy consumption in continuous integration (CI) environments. It provides functionality to calculate the energy consumption of CI jobs based on the power consumption characteristics of the underlying hardware.

## Usage

Eco-CI supports both GitHub and GitLab as CI platforms. When you integrate it into your pipeline, you must call the start-measurement script to begin collecting power consumption data, then call the get-measurement script each time you wish to make a spot measurement. When you call get-measurment, you can also assign a label to it to more easily identify the measurement. At the end, call the display-results to see all the measurement results, overall total usage, and export the data.

Follow the instructions below to integrate Eco-CI into your CI pipeline:

### Github:
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
      - name: Initialize Energy Estimation
        uses: green-coding-solutions/eco-ci-energy-estimation@v2 # use hash or @vX here (See note below)
        with:
          task: start-measurement

      - name: 'Checkout repository'
        uses: actions/checkout@v3
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v2 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'repo checkout'

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
        uses: green-coding-solutions/eco-ci-energy-estimation@v2 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'python setup'

      - name: Run Tests
        shell: bash
        run: |
          pytest

      - name: Tests measurement
        uses: green-coding-solutions/eco-ci-energy-estimation@v2 # use hash or @vX here (See note below)
        with:
          task: get-measurement
          label: 'pytest'

      - name: Show Energy Results
        uses: green-coding-solutions/eco-ci-energy-estimation@v2 # use hash or @vX here (See note below)
        with:
          task: display-results
```

#### Github Action Mandatory and Optional Variables:

- `task`: (required) (options are `start-measurement`, `get-measurement`, `display-results`)
  - `start-measurement` - Initialize the action starts the measurement. This must be called, and only once per job.
  - `get-measurement` - Measures the energy at this point in time since either the start-measurement or last get-measurement action call.
  - `display-results` - Outputs the energy results to the`$GITHUB_STEP_SUMMARY`. Creates a table that shows the energy results of all the get-measurements, and then a final row for the entire run. Displays the avergae cpu utilization, the total Joules used, and average wattage for each measurment+total run. It will also display a graph of the energy used, and a badge for you to display.
    - This badge will always be updated to display the total energy of the most recent run of the workflow that generated this badge.
    - The total measurement of this task is provided as output `data-total-json` in json format (see example below).
    - Can be used with `pr-comment` flag (see below) to post the results as a comment on the PR.
- `branch`: (optional) (default: ${{ github.ref_name }})
  - Used with `get_measurement` and `display_results` to correctly identify this CI run for the Badge.
- `label`: (optional) (default: 'measurement ##')
  - Used with `get_measurement` and `display_results` to identify the measurement
- `send-data`: (optional) (default: true)
  - Send metrics data to metrics.green-coding.io to create and display badge, and see an overview of the energy of your CI runs. Set to false to send no data. The data we send are: the energy value and duration of measurement; cpu model; repository name/branch/workflow_id/run_id; commit_hash; source (GitHub or GitLab). We use this data to display in our green-metrics-tool front-end here: https://metrics.green-coding.io/ci-index.html
- `show-carbon`: (optional) (default: true)
  - Gets the location using http://ip-api.com
  - Get the CO2 grid intensity for the location from https://www.electricitymaps.com/
  - Estimates the amount of carbon the measurement has produced
- `display-table`: (optional) (default: true)
  - call during the `display-graph` step to either show/hide the energy reading table results in the output
- `display-graph`: (optional) (default: true)
  - We use an ascii charting library written in go (https://github.com/guptarohit/asciigraph). For GitHub hosted runners their images come with go so we do not install it. If you are using a private runner instance however, your machine may not have go installed, and this will not work. As we want to minimize what we install on private runner machines to not intefere with your setup, we will not install go. Therefore, you will need to call `start-measurement` with the `display-graph` flag set to false, and that will skip the installation of this go library.
- `display-badge`: (optional) (default: true)
  - used with display-results
  - Shows the badge for the ci run during display-results step
  - automatically false if send-data is also false
- `pr-comment`: (optional) (default: false)
  - used with display-results
  - if on, will post a comment on the PR issue with the Eco-CI results. only occurs if the triggering event is a pull_request
  - remember to set `pull-requests: write` to true in your workflow file
- `api-base`: (optional) (default: 'api.github.com')
  - Eco-CI uses the github api to post/edit PR comments
  - set to github's default api, but can be changed if you are using github enterprise
- `company-uuid`: (optional)
  - If you want to add your CI/CD runs to the [CarbonDB](https://www.green-coding.io/projects/carbondb/) you can set your company uuid here. If you set this all your runs will be found for your company. Please note that if your CI is public your company uuid will be exposed and other people could check your CO2 footprint.
  - Please note that we will add the label as a tag so you can see which steps generated how much CO2
- `project-uuid`: (optional)
  - If you want to group your CI/CD runs by project
- `machine-uuid`: (optional)
  - If you want to make the runs look like they all ran on the same machine. This is not recommended as it will not be accurate but can be helpful for debugging.

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

We recommend running our action with `continue-on-error:true`, as it is not critical to the success of your workflow, but rather a nice feature to have.

```yaml
      - name: Eco CI Energy Estimation
        uses: green-coding-solutions/eco-ci-energy-estimation@v2
        with:
          task: final-measurement
        continue-on-error: true
```

#### Consuming the Measurements as JSON

For both tasks `get-measurement` and `display-results` the lap measurements and total measurement can be consumed in JSON format.
You can use the outputs `data-lap-json` or `data-total-json` respectively.
Here is an example demonstrating how this can be achieved:

```yaml
      # ...
      - name: 'Checkout repository'
        uses: actions/checkout@v3
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurment
        uses: green-coding-solutions/eco-ci-energy-estimation@v2
        id: checkout-step
        with:
          task: get-measurement
          label: 'repo checkout'

      - name: Print checkout data
        run: |
          echo "total json: ${{ steps.checkout-step.outputs.data-lap-json }}"

      - name: Show Energy Results
        uses: green-coding-solutions/eco-ci-energy-estimation@v2
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
      - name: Eco CI - Initialize
        uses: green-coding-solutions/eco-ci-energy-estimation@v2
        with:
          task: start-measurement
 ```

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
`initialize_energy_estimator` - used to setup the machine for measurement. Needs to be called once per VM job.
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
    - !reference [.initialize_energy_estimator, script]
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
- The Eco-CI at its core makes its energy estimations based on an XGBoost Machine Learning model we have created based on the SpecPower database. The model and further information can be found here: https://github.com/green-coding-solutions/spec-power-model
- When you initialize the Eco-CI, it downloads the XGBoost model onto the machine, as well as a small program to track the cpu utilization over a period of time. This tracking begins when you call the start_measurement function. Then, each time you call get-measurement, it will take the cpu-utilization data collected (either from the start, or since the last get-measurement call) and make an energy estimation based on the detected hardware (mainly cpu data) and utilization.

### Limitations
- At the moment this will only work with linux based pipelines, mainly tested on ubuntu images.

- If you have your pipelines split over multiple VM's (often the case with many jobs) ,you have to treat each VM as a seperate machine for the purposes of measuring and setting up Eco-CI.

- The XGBoost model requires the CPU to have a fixed frequency setting. This is typical for cloud testing, but not always the case.

- The XGBoost model data is trained via the SpecPower database, which was mostly collected on compute machines. Results will be off for non big cloud servers and also for machines that are memory heavy or machines which rely more heavily on their GPU's for computations.

### Note on the integration
- If you use dependabot and want to get updates, we recommend using the hash notation
  + `uses: green-coding-solutions/eco-ci-energy-estimation@06837b0b3b393a04d055979e1305852bda82f044 #v2.2`
  + Note that this hash is just an example. You find the latest current hash under *Tags*

- If you want the extension to automatically update within a version number, use the convenient @v2 form
  + `uses: green-coding-solutions/eco-ci-energy-estimation@v2 # will pick the latest minor v2. for example v2.2`


