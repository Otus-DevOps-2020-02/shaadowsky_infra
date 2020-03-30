# shaadowsky_infra
shaadowsky Infra repository

## application deployment

testapp_IP = 35.198.167.169

testapp_port = 9292

### работа с консолью gcloud

Устанавливаем _Google Cloud SDK_ - [инструкция вендора](https://cloud.google.com/sdk/install?hl=ru). Для Ubuntu 18.04 выглядит так:

```
# Add the Cloud SDK distribution URI as a package source
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list

# Import the Google Cloud Platform public key
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -

# Update the package list and install the Cloud SDK
sudo apt-get update && sudo apt-get install google-cloud-sdk
```

инициализируем SDK. Откроется окно с выбором к какому гуглаккаунту привязываться. Подробно [здесь](https://cloud.google.com/sdk/docs/quickstart-debian-ubuntu?hl=ru#initialize_the_sdk)

```
gcloud init
```

Проверить к какому гугл-аккаунту подключен можно так:

```
$ gcloud auth list
   Credentialed Accounts
ACTIVE  ACCOUNT
*       shaadowsky@gmail.com

To set the active account, run:
    $ gcloud config set account `ACCOUNT`
```

### создание инстансов из консоли gcloud

Синтаксис схож с командами qemu/libvirt

```
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
  ```

anything
