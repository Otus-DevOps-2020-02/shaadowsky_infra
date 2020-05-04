# shaadowsky_infra

## hw-09 Ansible-2

## Деплой и управление конфигурацией с Ansible

### prerequisites

команды даны для локальной убунту 1804лтс и 

```bash
$ ansible --version
ansible 2.9.7
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/home/shaad/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.17 (default, Apr 15 2020, 17:20:14) [GCC 7.5.0]
```

отключить провиженинг приложения в terraform: 

- либо выключить его с помощью переменной, если это было предусмотрено
- либо закомментировать или удалить код провижининга для app и db модулей

### Один playbook, один сценарий

Основное преимущество Ansible заключается в том, что
данный инструмент позволяет нам применять практику IaC,
давая возможность декларативно описывать желаемое
состояние наших систем в виде кода.
Код Ansible хранится в YAML файлах, называемых
плейбуками (playbooks) в терминологии Ansible.

Создадим плейбук для управления конфигурацией и деплоя
нашего приложения. Для этого создайте файл reddit_app.yml
в директории ./ansible

Чтобы не запушить в репу временные файлы Ansible,
добавим в файл .gitignore следующую строку:

```code
*.retry
```

Плейбук может состоять из одного или нескольких сценариев (plays). Сценарий позволяет группировать набор заданий (tasks),который Ansible должен выполнить на конкретном хосте (или группе). В нашем плейбуке мы будем использовать один сценарий для управления конфигурацией обоих хостов (приложения и БД).

создаем файл ./ansible/reddit_app.yaml:

```code
---
  - name: Configure hosts & deploy application # <-- Словесное описание сценария (name)
  hosts: all # <-- Для каких хостов будут выполняться описанные ниже таски (hosts)
  tasks: # <-- Блок тасков (заданий), которые будут выполняться для данных хостов
```

По умолчанию MongoDB слушает на localhost (127.0.0.1) и наше тестовое приложение работало без дополнительных настроек БД, когда приложение и БД находились на одном инстансе. Т.к. мы вынесли MongoDB на отдельный инстанс, то нам потребуется изменить конфигурацию MongoDB, указав ей слушать на имеющемся сетевом интерфейсе доступном для инстанса приложения, в противном случае наше приложение не сможет подключиться к БД.

Используем модуль template, чтобы скопировать параметризированный локальный конфиг файл MongoDB на удаленный хост по указанному пути. Добавим task в файл ansible/reddit_app.yml

```code
---
  - name: Configure hosts & deploy application 
  hosts: all # <-- Для каких хостов будут выполняться описанные ниже таски (hosts)
  tasks: # <-- Блок тасков (заданий), которые будут выполняться для данных хостов
    - name: change mongo config file
      become: true # от чьего имени будем выполнять, тут от рута
      template:
        src: templates/mongod.conf.j2 # путь до локального файла-шаблона
        dest: /etc/mongod.conf # путь куда положить на удалённом хосте
        mode: 0644 # какие права установить
```

Для каждого из наших тасков сразу будем определять тег, чтобы иметь возможность запускать отдельные таски, имеющие определенный тег, а не весь сценарий сразу.

Файл ansible/reddit_app.yml:

```code
---
  - name: Configure hosts & deploy application 
    hosts: all 
    tasks: 
      - name: change mongo config file
        become: true 
        template:
          src: templates/mongod.conf.j2 
          dest: /etc/mongod.conf 
          mode: 0644
        tags: db-tag # <-- Список тэгов для задачи
```

Создадим директорию templates внутри директории ansible. В директории ansible/templates создадим файл mongod.conf.j2 (расширение .j2 будет напоминать нам, что данный файл является шаблоном). Т.к. в нашем случае нас интересует возможность управления адресом и портом, на котором слушает БД, то мы параметризуем именно эти параметры конфигурации. Вставим в данный шаблон параметризованный конфиг для MongoDB.

Файл templates/mongod.conf.j2:

```code
# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true

# Where to write logging data.
  systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# Network interfaces
net:
  # default - один из фильтров Jinja2, он задает значение по умолчанию,
  # если переменная слева не определена
  port: {{ mongo_port | default('27017') }}
  bindIp: {{ mongo_bind_ip }} # <-- Подстановка значения переменной
```

Применение плейбука к хостам осуществляется при помощи команды ansible-playbook, у которой  есть опция --check которая позволяет произвести "пробный прогон" (dryrun) плейбука. Пробный прогон позволяет посмотреть, какие изменения
произойдут на хосте(ах) в случае применения плейбука (похоже а terraform plan), а также указывает на ошибки синтаксиса, если они есть. Опция --linit ограничивает группу хостов, для которых применяется плейбук.

```bash
$ ansible-playbook reddit_app.yml --check --limit db
...
TASK [Change mongo config file] ************************************************
fatal: [dbserver]: FAILED! => {"changed": false, "failed": true, "msg":
"AnsibleUndefinedVariable: 'mongo_bind_ip' is undefined"}
to retry, use: --limit @/Users/user/hw11/ansible/reddit_app.retry
PLAY RECAP *********************************************************************
dbserver : ok=1 changed=0 unreachable=0 failed=1
```

AnsibleUndefinedVariable - Ошибка❗ Переменная, которая используется в шаблоне не определена

Определим значения переменных в нашем плейбуке. Задавать переменную для порта не будем, т.к. нас устраивает значение по умолчанию, которое мы задали в шаблоне.

```code
---
  - name: Configure hosts & deploy application 
    hosts: all 
    vars:
      mongod_bind_ip: 0.0.0.0# <-- Переменная задается в блоке vars
    tasks: 
      - name: change mongo config file
        become: true 
        template:
          src: templates/mongod.conf.j2 
          dest: /etc/mongod.conf 
          mode: 0644
        tags: db-tag
```

