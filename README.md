# shaadowsky_infra
shaadowsky Infra repository, команды даны для выполнения на локальной Ubuntu 18.04

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
*       <some@mail.com>

To set the active account, run:
    $ gcloud config set account `ACCOUNT`
```

### создание инстансов из консоли gcloud

Синтаксис схож с командами qemu/libvirt.

Для указания startup скрипта используется конструкция _--metadata startup-script-url=<link>_ или _--metadata-from-file startup-script=<путь_до_скрипта>_

```
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small --tags puma-server \
  --restart-on-failure \
  --metadata startup-script-url=https://raw.githubusercontent.com/Otus-DevOps-2020-02/shaadowsky_infra/cloud-testapp/full_startup.sh
```

### deployment scripts

Созданы скрипты развертывания:

1. [установка ruby](install_ruby.sh)
2. [установка mongodb](install_mongodb.sh)
3. [установка приложения](deploy.sh)

скриптам установлен флаг исполняемости (_chmod +x_):

$ ll
-rwxr-xr-x 1 shaad shaad  175 мар 30 10:33 deploy.sh
-rwxr-xr-x 1 shaad shaad  397 мар 30 10:31 install_mongodb.sh
-rwxr-xr-x 1 shaad shaad  146 мар 30 10:33 install_ruby.sh

### создание разрешающего правила c помощью gcloud

```
gcloud compute firewall-rules \
  create puma-9292 --direction=INGRESS --priority=1000 \
  --network=default --action=ALLOW --rules=tcp:9292 \
  --source-ranges=0.0.0.0/0 --target-tags=puma-server
```


### Travis CI check

testapp_IP = 35.228.88.190

testapp_port = 9292
