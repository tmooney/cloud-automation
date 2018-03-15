#
# Helper script for 'gen3 workon' - see ../README.md and ../gen3setup.sh
# that other bin/ scripts can 'source'
#


source "$GEN3_HOME/gen3/lib/utils.sh"

AWS_VERSION=$(aws --version 2>&1 | awk '{ print $1 }' | sed 's@^.*/@@')
if ! semver_ge "$AWS_VERSION" "1.14.0"; then
  echo "ERROR: gen3 requires aws cli >= 1.14.0 - please update from ${AWS_VERSION}"
  echo "  see https://docs.aws.amazon.com/cli/latest/userguide/installing.html - "
  echo "  'sudo pip install awscli --upgrade' or 'pip install awscli --upgrade --user'"
  exit 1
fi

TERRAFORM_VERSION=$(terraform --version | head -1 | awk '{ print $2 }' | sed 's/^[^0-9]*//')
if ! semver_ge "$TERRAFORM_VERSION" "0.11.3"; then
  echo "ERROR: gen3 requires terraform >= 0.11.3 - please update from ${TERRAFORM_VERSION}"
  echo "  see https://www.terraform.io/downloads.html"
  exit 1
fi

if [[ -z "$GEN3_PROFILE" || -z "$GEN3_WORKSPACE" || -z "$GEN3_WORKDIR" || -z "$GEN3_HOME" || -z "$GEN3_S3_BUCKET" ]]; then
  echo "Must define runtime environment: GEN3_PROFILE, GEN3_WORKSPACE, GEN3_WORKDIR, GEN3_HOME"
  exit 1
fi


#
# This folder holds secrets, so lock it down permissions wise ...
#
umask 0077

if [[ $1 =~ ^-*help$ ]]; then
  help
  exit 0
fi

# Little string to prepend to info messages
DRY_RUN_STR=""
if $GEN3_DRY_RUN; then DRY_RUN_STR="--dryrun"; fi
