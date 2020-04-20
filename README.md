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
appserver ansible_host=<ip_address> ansible_user=appuser ansible_private_key_file=~/.ssh/appuser
```

проверяем, что ансибл подключяется к хосту:

```bash
$ cd ansible/
$ ansible appserver -i ./inventory -m ping
...
appserver | SUCCESS => {
...
    "ping": "pong"
}
```

Добавляем в инвентори хоcт dbserver. Для этого надо добавить для инстанса db внешнее соединение (посмотри в инстанс app, см. в инвенториn) и пересоздать проект (terraform apply)

Проверить внешний ip можно использовав _terraform show_

Проверяем доступность dbserver:

```bash
$ ansible dbserver -i inventory -m ping
...
    "changed": false, 
    "ping": "pong"
}
```

Для упрощения работы с инвентори создаём конфигурационный файл _ansible/ansible.cfg_ со следующим содержимым:

```code
[defaults]
inventory = ./inventory
remote_user = appuser
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
```

После этого можно убрать избыточную информацию из _inventory_ , сведя его к следующему содержанию:

```code
appserver ansible_host=<ip_address>
dbserver ansible_host=<ip_address>
```

Проверяем возможность подключения к dbserver:

```bash
$  ansible dbserver -m command -a uptime
...
dbserver | CHANGED | rc=0 >>
 07:27:45 up  2:27,  1 user,  load average: 0.00, 0.00, 0.00
```

Для удобства создаем группы хостов в _ansible/inventory_:

```code
[app] # ⬅ Это название группы
appserver ansible_host=<ip_address> # ⬅ Cписок хостов в данной группе

[db]
dbserver ansible_host=<ip_address>
```

Проверяем возможность пинговать сразу группу:

```bash
$ ansible app -m ping
... 
    "changed": false, 
    "ping": "pong"
}
```

В результате вышевыполненных действий получен инвентори в ini-формате. Возможно выполнять в [yaml-формате](ansible/inventory.yml), ознакомиться с документацией [тут](https://docs.ansible.com/ansible/latest/intro_inventory.html). Файлы корректно называет с окончанием yaml или yml.

Проверяем корректность (применяется группа all, явно не обозначенная, но существуюшая по логике ансибл):

```bash
$ ansible all -m ping -i inventory.yml
...
    "changed": false, 
    "ping": "pong"
}
...
    "changed": false, 
    "ping": "pong"
}
```

