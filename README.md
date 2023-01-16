# eco-ci-energy-estimation
Eco CI Energy estimation for Github Actions Runner VMs

## Usage

Here is a sample workflow that just creates a demo load.

You have to call `initialize` before doing any of your work and then `start-measurement`, when you want to start measuring.

Whenever you want to have some output of energy metrics in your `$GITHUB_STEP_SUMMARY` call `get-measurement`

```code


# This is a basic workflow to help you get started with Actions

name: Energy Test

# Controls when the workflow will run
on:
  # Allows you to run this workflow manually from the Actions tab
  workflow_dispatch:

# A workflow run is made up of one or more jobs that can run sequentially or in parallel
jobs:
  # This workflow contains a single job called "build"
  build:
    # The type of runner that the job will run on
    runs-on: ubuntu-latest

    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
      - uses: green-coding-berlin/eco-ci-energy-estimation@v1
        with:
          task: initialize

      - uses: green-coding-berlin/eco-ci-energy-estimation@v1
        with:
          task: start-measurement

      - name: Doing load
        run: sleep 5
        continue-on-error: true

      - uses: green-coding-berlin/eco-ci-energy-estimation@v1
        with:
          task: get-measurement
     # end
```


## Design decisions for the energy estimation action
The goal of this action is to empower Github Action users to estimate the energy of the Github hosted runner VMs in an easy fashion with minimal integration overhead into existing workflows.

The initial idea was to use the Javascript Actions of Github Actions that have a nice callback mechanism through their main and post action.

main would initialize the estimation model and then start the measurement. Once the workflow run completes the metrics are outputted to the $GITHUB_STEP_SUMMARY.

However in Javascript Actions it is not possible to use easily use the Github Actions cache. An example how github does it in its own actions can be seen here ... which is brutal to say the least. (To be fair, there seems to be a simpler method available, but we could not find any good documentation on it: https://snyk.io/advisor/npm-package/@actions/cache/functions/@actions%2Fcache.restoreCache)

Since copying, adapting and maintaining that code was no option we resorted to using the composite Github Action as an alternative.

Here we have to call the Action three times: initialize, start-measurement, end-measurement

This however also gives us the benefit of making a "lap" and stopping and restarting a measurement with an intermediate metrics output.
