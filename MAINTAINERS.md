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

### Deprecate old tags

This step is necessary if you do not want to support some versions anymore.
Typically when the GMT API has been deprecated or some strong calculation error was found.

```bash
git fetch origin --tags --force

# 0. Backup of the current tag -> SHA mapping (for rollback)
TAGS="v5.0 v5.1" # list all!
for t in $TAGS; do echo "$t $(git rev-parse "$t^{commit}")"; done > ~/eco-ci-tag-backup.txt

# 1. Move to deprecation branch
git switch deprecated
DEPRECATED_SHA=$(git rev-parse HEAD)

# 2. Move all old tags locally
for t in $TAGS; do git tag -f "$t" "$DEPRECATED_SHA"; done

# 3. Check, then force-push all tags in a single push
git tag --points-at "$DEPRECATED_SHA" | wc -l    # expect 34
git push --force origin $(for t in $TAGS; do printf 'refs/tags/%s ' "$t"; done)

git switch main
