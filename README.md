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

Проверяем версии ruby и bundler. Применяется модуль shell, т.к. модуль command не умеет выполнять сразу две команды, т.к. не использует оболочку (*sh), поэтому в нём не работют перенаправления потоков и нет доступа к некоторым переменным окружения.

Проверять статус службы можно с использованием модулей command, shell, systemd и service. Последний является наиболее универсальным, т.к. до сих пор встречаются ОС с init.d-инициализацией.

```bash
$ ansible db -m command -a 'systemctl status mongod'

dbserver | CHANGED | rc=0 >>
* mongod.service - High-performance, schema-free document-oriented database
   Loaded: loaded (/lib/systemd/system/mongod.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2020-04-20 04:59:58 UTC; 2h 55min ago

$ ansible db -m shell -a 'systemctl status mongod'

dbserver | CHANGED | rc=0 >>
* mongod.service - High-performance, schema-free document-oriented database
   Loaded: loaded (/lib/systemd/system/mongod.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2020-04-20 04:59:58 UTC; 2h 55min ago

$ ansible db -m systemd -a name=mongod
...
        "ActiveState": "active", 

$  ansible db -m service -a name=mongod
...
        "ActiveState": "active", 
```

Модули systemd и service возвращают ответ в виде набора переменных, которые можно использовать в дальнейшем коде.

Для клонирования репозитория с приложением на сервер используется модуль git. Обрати внимание,  возвращается false, т.к. содержимое репозитория не изменилось с момента развёртывания.

```bash
$ ansible app -m git -a 'repo=https://github.com/express42/reddit.git dest=/home/appuser/reddit'

appserver | SUCCESS => {
    "after": "5c217c565c1122c5343dc0514c116ae816c17ca2", 
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    }, 
    "before": "5c217c565c1122c5343dc0514c116ae816c17ca2", 
    "changed": false, 
    "remote_url_changed": false
}
```

Модуль command при повторном развёртывании выдасть ошибку по той же причине:

```bash
$ ansible app -m command -a 'git clone https://github.com/express42/reddit.git /home/appuser/reddit'

appserver | FAILED | rc=128 >>
fatal: destination path '/home/appuser/reddit' already exists and is not an empty directory.non-zero return code
```

создаём плейбук клонирования приложения - _ansible/clone.yml_:

```code
---
- name: Clone
  hosts: app
  tasks:
    - name: Clone repo
      git:
        repo: https://github.com/express42/reddit.git
        dest: /home/appuser/reddit
```

и проверяем выполнение:

```bash
$ ansible-playbook clone.yml

PLAY RECAP *********************************************************************************
appserver                  : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

