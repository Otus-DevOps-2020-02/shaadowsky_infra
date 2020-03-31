gcloud compute instances create reddit-full\
  --boot-disk-size=15GB --image-family reddit-full \
  --image-project=infra-272603 --machine-type=f1-micro \
  --tags puma-server --restart-on-failure
