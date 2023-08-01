# Eco-CI

Eco-CI is a project aimed at estimating energy consumption in continuous integration (CI) environments. It provides functionality to calculate the energy consumption of CI jobs based on the power consumption characteristics of the underlying hardware.

## Usage

Eco-CI supports both GitHub and GitLab as CI platforms. When you integrate it into your pipeline, you must call the start-measurement script to begin collecting power consumption data, then call the get-measurement script each time you wish to make a spot measurement. When you call get-measurment, you can also assign a label to it to more easily identify the measurement. At the end, call the display-results to see all the measurement results, overall total usage, and export the data. 

Follow the instructions below to integrate Eco-CI into your CI pipeline:

### Github:
To use Eco-CI in your github workflow, call it with the relevant task name (start-measurement, get-measurement, or display-results). Here is a sample workflow that runs some python tests with eco-ci integrated.

```yaml
name: Daily Tests with Energy Measurement
run-name: Scheduled - DEV Branch
on:
  schedule:
    - cron: '0 0 * * *'

jobs:
  run-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Initialize Energy Estimation
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
        with:
          task: start-measurement

      - name: 'Checkout repository'
        uses: actions/checkout@v3
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurement
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
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
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
        with:
          task: get-measurement
          label: 'python setup'

      - name: Run Tests
        shell: bash
        run: |
          pytest

      - name: Tests measurement
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
        with:
          task: get-measurement
          label: 'pytest'

      - name: Show Energy Results
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
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
    - Send metrics data to metrics.green-coding.berlin to create and display badge, and see an overview of the energy of your CI runs. Set to false to send no data. The data we send are: the energy value and duration of measurement; cpu model; repository name/branch/workflow_id/run_id; commit_hash; source (github or gitlab). We use this data to display in our green-metrics-tool front-end here: https://metrics.green-coding.berlin/ci-index.html 
- `display-table`: (optional) (default: true)
    - call during the `display-graph` step to either show/hide the energy reading table results in the output
- `display-graph`: (optional) (default: true)
    - We use an ascii charting library written in go (https://github.com/guptarohit/asciigraph). For github hosted runners their images come with go so we do not install it. If you are using a private runner instance however, your machine may not have go installed, and this will not work. As we want to minimize what we install on private runner machines to not intefere with your setup, we will not install go. Therefore, you will need to call `start-measurement` with the `display-graph` flag set to false, and that will skip the installation of this go library.
- `display-badge`: (optional) (default: true)
    - used with display-results
    - Shows the badge for the ci run during display-results step
    - automatically false if send-data is also false
- `pr-comment`: (optional) (default: false)
    - used with display-results
    - if on, will post a comment on the PR issue with the Eco-CI results

#### Continuing on Errors

We recommend running our action with `continue-on-error:true`, as it is not critical to the success of your workflow, but rather a nice feature to have.

```yaml
      - name: Eco CI Energy Estimation
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
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
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
        id: checkout-step
        with:
          task: get-measurement
          label: 'repo checkout'

      - name: Print checkout data
        run: |
          echo "total json: ${{ steps.checkout-step.outputs.data-lap-json }}"      
      
      - name: Show Energy Results
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
        id: total-measurement-step
        with:
          task: display-results

      - name: Print total data
        run: |
          echo "total json: ${{ steps.total-measurement-step.outputs.data-total-json }}"
```

Note that the steps you want to consume the measurements of need to have an `id` so that you can access the corresponding data from their outputs.

#### Note on private repos
 If you are running in a private repo, you must give your job actions read permissions for the github token. This  is because we make an api call to get your workflow_id which uses your `$GITHUB_TOKEN`, and it needs the correct permissions to do so:
 ```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      actions: read
    steps:
      - name: Eco CI - Initialize
        uses: green-coding-berlin/eco-ci-energy-estimation@v2
        with:
          task: start-measurement
 ```  

### Gitlab:
To use Eco-CI in your gitlab pipeline, you must first include a reference to the eco-ci-gitlab.yml file as such:
```
include:
  remote: 'https://raw.githubusercontent.com/green-coding-berlin/eco-ci-energy-estimation/main/eco-ci-gitlab.yml'
```

and you call the various scripts in your pipeline with call like this:
```
- !reference [.<function-name>, script]
```
where function name is one of the following:
`initialize_energy_estimator` - used to setup the machine for measurement. Needs to be called once per VM job.
`start_measurement` - begin the measurment
`get_measurement` - make a spot measurment here. If you wish to label the measurement, you need to set the ECO_CI_LABEL environment variable right before this call.
`display_results` - will print all the measurement values to the jobs-output and prepare the artifacts, which must be exported in the normal gitlab way.

By default, we send data to our API, which will allow us to present you with a badge, and a front-end display to review your results. The data we send are: the energy value and duration of measurement; cpu model; repository name/branch/workflow_id/run_id; commit_hash; source (github or gitlab). We use this data to display in our green-metrics-tool front-end here: https://metrics.green-coding.berlin/ci-index.html 

If you do not wish to send us data, you can set this global variable in your pipeline:

```
variables:
  ECO_CI_SEND_DATA: "false"
```

Then, for each job you need to export the artifacts. We currently export the pipeline data as a regular artifact, as well as make use of Gitlab's [Metric Report](https://docs.gitlab.com/ee/ci/testing/metrics_reports.html) artifact (which we output to the default metrics.txt):

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
  remote: 'https://raw.githubusercontent.com/green-coding-berlin/eco-ci-energy-estimation/main/eco-ci-gitlab.yml'

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
- The Eco-CI at its core makes its energy estimations based on an XGBoost Machine Learning model we have created based on the SpecPower database. The model and further information can be found here: https://github.com/green-coding-berlin/spec-power-model
- When you initialize the Eco-CI, it downloads the XGBoost model onto the machine, as well as a small program to track the cpu utilization over a period of time. This tracking begins when you call the start_measurement function. Then, each time you call get-measurement, it will take the cpu-utilization data collected (either from the start, or since the last get-measurement call) and make an energy estimation based on the detected hardware (mainly cpu data) and utilization.

### Limitations
- At the moment this will only work with linux based pipelines, mainly tested on ubuntu images.

- If you have your pipelines split over multiple VM's (often the case with many jobs) ,you have to treat each VM as a seperate machine for the purposes of measuring and setting up Eco-CI.

- The XGBoost model requires the CPU to have a fixed frequency setting. This is typical for cloud testing, but not always the case. 

- The XGBoost model data is trained via the SpecPower database, which was mostly collected on compute machines. Results will be off for non big cloud servers and also for machines that are memory heavy or machines which rely more heavily on their GPU's for computations.
