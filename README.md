# shaadowsky_infra

## hw-08 Ansible-1

## Знакомство с Ansible

### prerequisites

команды даны для выполнения на локальной Ubuntu 18.04

1. Python 2.7.17
2. pip 20.0.2 from /home/shaad/.local/lib/python2.7/site-packages/pip (python 2.7)
3. ansible 2.9.6

### выполнение

создаем в директории _ansible/_ файл _requirements.txt_

```bash
mkdir ansible
echo "ansible>=2.4" > ansible/requirements.txt
```

установить ansible любым способом:

```
pip install -r requirements.txt
pip install ansible>=2.4
easy_install `cat requirements.txt`
yum install ansible
apt install ansible
```

Поднять приложение из окружения stage

```bash
cd terraform/stage
terraform init
terraform apply -auto-approve -parallelism=5
```

Создадим инвентори файл ansible/inventory, в котором укажем информацию о созданном инстансе приложения и параметры подключения к нему по SSH:

```code
appserver ansible_host=35.228.88.190 ansible_user=appuser ansible_private_key_file=~/.ssh/appuser
```

проверяем, что ансибл подключяется к хосту:

```bash
$ cd ansible/
$ ansible appserver -i ./inventory -m ping
The authenticity of host '35.228.88.190 (35.228.88.190)' can't be established.
ECDSA key fingerprint is SHA256:dI8TaLlzSS3pemvUVdoLYm8Eutl4W9IHbjMUEYvr/RE.
Are you sure you want to continue connecting (yes/no)? yes
...
appserver | SUCCESS => {
...
    "ping": "pong"
}
```

Добавляем в инвентори хоcт dbserver. Для этого надо добавить для инстанса db внешнее соединение (посмотри в инстанс app, скопируй секции network_interface и connection) и пересоздать проект (terraform apply)

