# eco-ci-energy-estimation
Eco CI Energy estimation for Github Actions Runner VMs

## Usage

When you use the eco-ci energy estimator, you must call it with one of three tasks: `start-measurement`, `get-measurement`, `display-results`. Call `start-measurement` once to initialize the action, `get-measurement` at each point you want to make a spot measurement, and `display-results` at the end send output to your GITHUB_STEP_SUMMARY. 

### Detailed information on the tasks:
- `start-measurement` - Initialize the action starts the measurement. This must be called, and only once per job.
    - We use an ascii charting library written in go (https://github.com/guptarohit/asciigraph). For github hosted runners their images come with go so we do not install it. If you are using a private runner instance however, your machine may not have go installed, and this will not work. As we want to minimize what we install on private runner machines to not intefere with your setup, we will not install go. Therefore, you will need to call this step with the `display-graph` flag set to false, and that will skip the installation of this go library.
- `get-measurement` - Measures the energy at this point in time since either the start-measurement or last get-measurement action call. 
    - This can optionally take a 'label' parameter that will be used as a label for the measurement
    - It also optionally takes a 'branch' parameter. This uses the `{{ github.ref_name }}` by default to identify the exact workflow run this energy measurement belongs to, but in case your CI runs against a different branch than what {{ github.ref_name }} gives you, you can set it here.
    - We send data to our servers in order to build a page to display your energy usage over time at metrics.green-coding.berlin. If you do not wish to send any data over, you can call this step with an optional flag:
    `send-data:false`
    - The measurement of this task is provided as output `data-lap-json` in json format (see example below).
- `display-results` - Outputs the energy results to the`$GITHUB_STEP_SUMMARY`. Creates a table that shows the energy results of all the get-measurements, and then a final row for the entire run. Displays the avergae cpu utilization, the total Joules used, and average wattage for each measurment+total run. It will also display a graph of the energy used, and a badge for you to display.
    - This badge will always be updated to display the total energy of the most recent run of the workflow that generated this badge.
    - this task also optionally takes the branch and label parameters.
    - creating the badge requires sending the energy data to our api. If you do not wish to send any data, call this step with the `send-data: false` flag as well.
    - The total measurement of this task is provided as output `data-total-json` in json format (see example below).
    - We also provide a few optional flags to minimize the output to your github_step_summary if you so desire (each of these are true by default:
        - `display-table` - set to false to not display the results table
        - `display-graph` - set to false to not display the energy usage over time graph
        - `display-badge` - set to false to not display the badge info and link

Here is a sample workflow that runs some python tests.

```yaml
name: Daily Tests with Energy Measurement
run-name: Scheduled - DEV Branch
on:
  schedule:
    - cron: '0 0 * * *'
  workflow_dispatch:

jobs:
  run-tests:
    runs-on: ubuntu-latest
    steps:
      - name: Initialize Energy Estimation
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: start-measurement

      - name: 'Checkout repository'
        uses: actions/checkout@v3
        with:
          ref: 'dev'
          submodules: 'true'

      - name: Checkout Repo Measurement
        uses: green-coding-berlin/eco-ci-energy-estimation@main
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
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: get-measurement
          label: 'python setup'

      - name: Run Tests
        shell: bash
        run: |
          pytest

      - name: Tests measurement
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: get-measurement
          label: 'pytest'

      - name: Show Energy Results
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: display-results
```

### Continuing on Errors

We recommend running our action with `continue-on-error:true`, as it is not critical to the success of your workflow, but rather a nice feature to have.

```yaml
      - name: Eco CI Energy Estimation
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: final-measurement
        continue-on-error: true
```

### Opt-out from Sending Measurement Data

If you do not wish to send data, call the `get-measurement` and `display-results` steps with `send-data: false`

```yaml
      - name: Tests measurement
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: get-measurement
          label: 'pytest'
          send-data: false

      - name: Show Energy Results
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: 
          
          
          
          send-data: false
```

### Consuming the Measurements as JSON

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
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        id: checkout-step
        with:
          task: get-measurement
          label: 'repo checkout'

      - name: Print checkout data
        run: |
          echo "total json: ${{ steps.checkout-step.outputs.data-lap-json }}"      
      
      - name: Show Energy Results
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        id: total-measurement-step
        with:
          task: display-results

      - name: Print total data
        run: |
          echo "total json: ${{ steps.total-measurement-step.outputs.data-total-json }}"
```

Note that the steps you want to consume the measurements of need to have an `id` so that you can access the corresponding data from their outputs.

### If running on a private repo without go isntalled
Make sure to run both the `start-measurement` and `display-results` step with `display-graph` set to false
```yaml
      - name: Initialize Measurment
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: start-measurement
          display-graph: false

      - name: Show Energy Results
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: display-results
          display-graph: false
```

## Note on private repos
 If you are running in a private repo, you must give your job actions read permissions for the github token. This  is because we make an api call to get your workflow_id which uses your `$GITHUB_TOKEN`, and it needs the correct permissions to do so:
 ```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      actions: read
    steps:
      - name: Eco CI - Initialize
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: start-measurement
 ```  

## Design decisions for the energy estimation action
The goal of this action is to empower Github Action users to estimate the energy of the Github hosted runner VMs in an easy fashion with minimal integration overhead into existing workflows.

The initial idea was to use the Javascript Actions of Github Actions that have a nice callback mechanism through their main and post action.

main would initialize the estimation model and then start the measurement. Once the workflow run completes the metrics are outputted to the `$GITHUB_STEP_SUMMARY`.

However, in Javascript Actions it is not possible to easily use the Github Actions cache. An example how github does it in its own actions can be seen here ... which is brutal to say the least. (To be fair, there seems to be a simpler method available, but we could not find any good documentation on it: https://snyk.io/advisor/npm-package/@actions/cache/functions/@actions%2Fcache.restoreCache)

Since copying, adapting and maintaining that code was no option we resorted to using the composite Github Action as an alternative.

Here we have to call the Action three times: `start-measurement`, `get-measurement`, `final-measurement`

This however also gives us the benefit of making a "lap" and stopping and restarting a measurement with an intermediate metrics output.
