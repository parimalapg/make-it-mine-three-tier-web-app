#!/usr/bin/env bash

# check variables
echo "Project: $PROJECT_ID"

#ToDo - Find a way to get these values.
# One way could be to make list call(for all locations?) with label filtering, filter=labels.goog-solutions-console-solution-id=\"three-tier-web-app\
DEPLOYMENT_ID="tiered-web-app"
REGION="us-central1"
ZONE="us-central1-a"

# List of iam roles required to deploy solution
iam_roles_list=(
	"roles/artifactregistry.admin"
	"roles/cloudsql.admin"
	"roles/compute.networkAdmin"
	"roles/iam.serviceAccountAdmin"
	"roles/iam.serviceAccountUser"
	"roles/redis.admin"
	"roles/resourcemanager.projectIamAdmin"
	"roles/run.admin"
	"roles/servicenetworking.serviceAgent"
	"roles/serviceusage.serviceUsageViewer"
	"roles/vpcaccess.admin"
  )
# fetch SA from existing deployment
service_account=$(curl\
       -H "Authorization: Bearer $(gcloud auth print-access-token)"\
       -H "Content-Type: application/json"\
       "https://config.googleapis.com/v1alpha2/projects/${PROJECT_ID}/locations/${REGION}/deployments/${DEPLOYMENT_ID}" | \
       grep -oP '(?<="serviceAccount": ")[^"]*' | grep -oP '(?<=serviceAccounts/).*')
# Assigning permissions to SA
for iam_role in ${iam_roles_list[@]}; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
   --member="serviceAccount:$service_account" \
   --role="$iam_role"
done
# updating deployment
curl \
    -X PATCH \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    "https://config.googleapis.com/v1alpha2/projects/${PROJECT_ID}/locations/${REGION}/deployments/${DEPLOYMENT_ID}" \
    --data @- <<EOF
    {
      "terraform_blueprint": {
        "git_source": {
		      "repo": "https://github.com/parimalapg/make-it-mine-three-tier-web-app",
 		      "ref": "cloudbuild-ci-cd-pipeline"
        },
        "input_values": {
          "project_id": {
            "input_value": "${PROJECT_ID}"
          },
	        "region": {
	          "input_value": "${REGION}"
          },
          "zone": {
	          "input_value": "${ZONE}"
          }
        }
      }
    }
EOF

while : ; do
  # get deployment state
  state=$(curl\
       -H "Authorization: Bearer $(gcloud auth print-access-token)"\
       -H "Content-Type: application/json"\
       "https://config.googleapis.com/v1alpha2/projects/${PROJECT_ID}/locations/${REGION}/deployments/${DEPLOYMENT_ID}" | grep -oP '(?<="state": ")[^"]*')
  echo "Deployment state: $state"
  # continue the loop if deployment is still updating
  [ "$state" == "UPDATING" ] || break
  # sleep for 60s
  sleep 60
done

# exit status 0 only if deployment succeeds
if [ "$state" == "ACTIVE" ]; then
  echo "UpdateDeployment Succeeded";
  exit 0
else
  echo "UpdateDeployment Failed";
  exit 1
fi;
