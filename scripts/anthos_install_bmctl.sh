source ~/variables.sh

echo '======Installing BMCTL======'
# Install Anthos CLI (bmctl)
cd ~
echo "creating baremetal folder"
mkdir -p baremetal
cd baremetal

gsutil cp gs://anthos-baremetal-release/bmctl/$ANTHOS_VERSION/linux-amd64/bmctl bmctl
chmod a+x bmctl

# Create Anthos configuration template
chmod 600 ~/.ssh/id_rsa
chmod 600 ~/google_application_credentials

cd ~/baremetal
./bmctl create config -c $ANTHOS_CLUSTER_NAME \
  --enable-apis --create-service-accounts --project-id=$GOOGLE_PROJECT_ID
