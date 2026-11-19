# Maintainer Instructions

With every release also the old tags have to be updated and the version number in `setup.sh` has to be bumped.

## Version Number

Change `ECO_CI_VERSION` in `setup.sh` to the newest version

## Tags

### Example: New release v6.0.0
Just create the new tags v6.0.0, v6 and v6.0 and publish the release for v6.0.0

Run this:
```bash
bash update-tag.sh v6.0.0
bash update-tag.sh v6.0
bash update-tag.sh v6
```

### Example: New release v5.2.1
This is a bugfix release and means you have to update all minor and major tags.

The workflow is the same but under the hood the tags are re-written on origin.
```bash
bash update-tag.sh v5.2.1
bash update-tag.sh v5.2
bash update-tag.sh v5
```
