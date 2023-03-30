# eco-ci-energy-estimation
Eco CI Energy estimation for Github Actions Runner VMs

## Usage

When you use the eco-ci energy estimator, you must call it with one of three tasks:

- `start-measurement` - Initialize the action starts the measurement. THis must be called, and only once per job.
- `get-measurement` - Must be called at least once per job. Measures the energy at this point in time since either the start-measurement or last get-measurement action call. Outputs the current measurement to the `$GITHUB_STEP_SUMMARY`
    - This can optionally take a 'label' parameter that will be used as a label for the measurement
    - It also optionally takes a 'branch' parameter. This uses the {{ github.ref_name }} by default to identify the exact workflow run this energy measurement belongs to, but in case your CI runs against a different branch than what {{ github.ref_name }} gives you, you can set it here.
- `end-measurement` - Gets a measurement of the *total* energy use of the job since you called start measurement, and displays this alongside a graph to the `$GITHUB_STEP_SUMMARY`. Also provides a link to a badge you can use to display the energy use.
    - This badge will always be updated to display the total energy of the most recent run of the workflow that generated this badge.
    - The energy displayed on this badge will be slightly different than what is displayed as for the total energy use. This badge will sum up and display the energy used by each instance of get-measurement before it- which is why get-measurement must be called at least one time before this step.
    - this task also optionally takes the branch parameter.


Here is a sample workflow that runs some python tests.

```code
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

      - name: Checkout Repo Measurment
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

      - name: Checkout Repo Measurment
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

      - name: Eco CI Energy Estimation
        uses: green-coding-berlin/eco-ci-energy-estimation@main
        with:
          task: end-measurement
```


## Design decisions for the energy estimation action
The goal of this action is to empower Github Action users to estimate the energy of the Github hosted runner VMs in an easy fashion with minimal integration overhead into existing workflows.

The initial idea was to use the Javascript Actions of Github Actions that have a nice callback mechanism through their main and post action.

main would initialize the estimation model and then start the measurement. Once the workflow run completes the metrics are outputted to the $GITHUB_STEP_SUMMARY.

However in Javascript Actions it is not possible to use easily use the Github Actions cache. An example how github does it in its own actions can be seen here ... which is brutal to say the least. (To be fair, there seems to be a simpler method available, but we could not find any good documentation on it: https://snyk.io/advisor/npm-package/@actions/cache/functions/@actions%2Fcache.restoreCache)

Since copying, adapting and maintaining that code was no option we resorted to using the composite Github Action as an alternative.

Here we have to call the Action three times: start-measurement, get-measurement, end-measurement

This however also gives us the benefit of making a "lap" and stopping and restarting a measurement with an intermediate metrics output.
