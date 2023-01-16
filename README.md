# eco-ci-energy-estimation
Eco CI Energy estimation for Github Actions Runner VMs


## Design decisions for the energy estimation action
The goal of this action is to empower Github Action users to estimate the energy of the Github hosted runner VMs in an easy fashion with minimal integration overhead into existing workflows.

The initial idea was to use the Javascript Actions of Github Actions that have a nice callback mechanism through their main and post action.

main would initialize the estimation model and then start the measurement. Once the workflow run completes the metrics are outputted to the $GITHUB_STEP_SUMMARY.

However in Javascript Actions it is not possible to use easily use the Github Actions cache. An example how github does it in its own actions can be seen here ... which is brutal to say the least. (To be fair, there seems to be a simpler method available, but we could not find any good documentation on it: https://snyk.io/advisor/npm-package/@actions/cache/functions/@actions%2Fcache.restoreCache)

Since copying, adapting and maintaining that code was no option we resorted to using the composite Github Action as an alternative.

Here we have to call the Action three times: initialize, start-measurement, end-measurement

This however also gives us the benefit of making a "lap" and stopping and restarting a measurement with an intermediate metrics output.
