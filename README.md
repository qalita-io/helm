# Helm Charts Repository

<p align="center">
  <img width="250px" height="auto" src="https://cloud.platform.qalita.io/logo.svg" style="max-width:250px;"/>
</p>

[![Badge](https://github.com/qalita-io/helm/workflows/Release%20Charts/badge.svg?branch=main)](https://github.com//qalita-io/helm/actions)
[![Artifact HUB](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/qalita)](https://artifacthub.io/packages/search?repo=qalita)

Welcome to QALITA's charts repository. All charts are in the charts directory.

## Adding the chart Repository

```bash
helm repo add qalita https://helm.qalita.io/
helm repo update
```

## Contributing

Feel free to fork our repo and create a pull request with any new features or bug fixes.

To dev the helm charts you can use a docker image :

```bash
docker run -d --rm -v $(pwd):/apps -w /apps \
    -v ~/.kube:/root/.kube -v ~/.helm:/root/.helm -v ~/.config/helm:/root/.config/helm \
    -v ~/.cache/helm:/root/.cache/helm \
    -v ~/helm/:/root/helm \
    --entrypoint sh \
    alpine/helm -c "sleep infinity"
```

## Contacting us

For issues or concerns, please fill out an issue or email us at contact@qalita.io

## How It Works

GitHub Pages points to the `gh-pages` branch so anything pushed to that branch will be publicly available. We are using a couple github actions to automate testing and deployment of charts. It is based off the example [here](https://github.com/helm/charts-repo-actions-demo).

## Process to add a chart to the repository

1. Create a branch or fork for your new chart
1. Initialize new chart in the `charts` directory with `helm create mychart` or by copying in your work from outside
1. After chart development is done, run (at minimum) `helm lint mychart/` to validate yaml and templates
1. Don't forget to bump your chart version (if needed)
1. Create a pull request with the new chart or updates
1. Once the PR is approved, the automation will publish the chart to our repository

## Notes about current testing

Testing is currently done with Helm3

## License

[Proprietary License](./LICENSE).
