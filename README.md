# shaadowsky_infra

## hw-10 Ansible-3

## Ansible: работа с ролями и окружениями

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

**_все работы выполнены в окружении stage_**

### Роли

Организация конфигурационного кода стала выглядеть лучше, после того как введено несколько плейбуков, но всё равно есть проблемы:
1.  шаблоны и файлы хранятся в одних и тех же директориях для всех плейбуков. Как результат, становится сложно понять, что к чему относится, особенно если у нас возрастет количество плейбуков.
2. т.к. переменных в плейбуке может быть большое
количество, их не очень удобно определять в самом плейбуке. Нам
определенно хотелось бы вынести их в отдельный файл.
3. текущую конфигурацию сложно версионировать и тяжело подстраивать для различных окружений.

Из чего следует, что плейбуки не подходят как формат для распространения и переиспользования кода (нет версии, зависимостей и метаданных, зато много хардкода)

Роли представляют собой основной механизм группировки и переиспользования конфигурационного кода в Ansible.

Роли позволяют сгруппировать в единое целое описание конфигурации отдельных сервисов и компонент системы (таски, хендлеры, файлы, шаблоны, переменные). Роли можно затем переиспользовать при настройке окружений, тем самым избежав дублирования кода.

Ролями можно также делиться и брать у сообщества (community) в [Ansible Galaxy](https://galaxy.ansible.com/)

Ansible Galaxy - это централизованное место, где хранится информация о ролях, созданных сообществом (community roles). Ansible имеет специальную команду для работы с Galaxy. Получить справку по этой команде можно на сайте или использовав команду:

```command
ansible-galaxy -h
```

Также команда _ansible-galaxy init_ позволяет нам создать структуру роли в соответсвии с принятым на Galaxy форматом. Мы не будем делиться созданными нами ролями на Galaxy, однако используем эту команду для создания заготовки ролей. В директории ansible создайте директорию roles и выполните в ней следующие команды для создания заготовки ролей для конфигурации нашего приложения и БД:

```bash
$ ansible-galaxy init app
- Role app was created successfully
$ ansible-galaxy init db
- Role db was created successfully
```

Посмотрим структуру созданных заготовок:

```bash
$ tree db
db
├── defaults          # <-- Директория для переменных по умолчанию
│   └── main.yml
├── files
├── handlers
│   └── main.yml
├── meta              # <-- Информация о роли, создателе и зависимостях
│   └── main.yml
├── README.md
├── tasks             # <-- Директория для тасков
│   └── main.yml
├── templates
├── tests
│   ├── inventory
│   └── test.yml
└── vars              # <-- Директория для переменных, которые не должны
    └── main.yml      # переопределяться пользователем

8 directories, 8 files
```

#### Роль дл БД

Продолжим создание роли для БД, папка roles/db уже создана после выполнения _ansible-galaxy init db_. Скопируем секцию _tasks_ из сценария плейбука _ansible/db.yml_ и вставляем её в файл в директорию _task_ роли _db_.

Файл ansible/roles/db/tasks/main.yml:

```code
# tasks file for db
- name: Change mongo config file
  template:
    src: templates/mongod.conf.j2
    dest: /etc/mongod.conf
    mode: 0644
  notify: restart mongod
```

В директорию шаблоннов роли _ansble/roles/db/templates_ скопируем шаблонизированный конфиг для MongoDB из директории ansible/templates.

Особенностью ролей также является, что модули template и copy, которые используются в тасках роли, будут по умолчанию проверять наличие шаблонов и файлов в директориях роли templates и files соответственно.

Поэтому укажем в таске только имя шаблона в качестве источника.

Файл _ansible/roles/db/tasks/main.yml_:

```code
- name: Change mongo config file
  template:
    src: mongod.conf.j2
    dest: /etc/mongod.conf
    mode: 0644
  notify: restart mongod
```

определим уже используемый хендлер в директории _handlers_ роли.

Файл _ansible/roles/db/handlers/main.yml_:

```code
# handlers file for db
- name: restart mongod
  service: name=mongod state=restarted
```

Определим используемые в шаблоне переменные в секции переменных по умолчанию (файл _ansible/roles/db/defaults/main.yml_):

```code
# defaults file for db
mongo_port: 27017
mongo_bind_ip: 127.0.0.1
```

Скопируем шаблон _ansible/templates/mongod.conf.j2_ в _ansible/roles/db/templates_

#### Роль для приложения

Скопируем секцию tasks в сценарии плейбука ansible/app.yml и вставим ее в файл для тасков роли app. Не забудем при этом заменить src в модулях copy и template для указания только имени файлов.

_ansible/roles/app/tasks/main.yml_:

```code
- name: Add unit file for Puma
  copy:
    src: puma.service
    dest: /etc/systemd/system/puma.service
  notify: reload puma
  
- name: Add config for DB connection
  template:
    src: db_config.j2
    dest: /home/appuser/db_config
    owner: appuser
    group: appuser
  
- name: enable puma
  systemd: name=puma enabled=yes
```

Скопируйте файл _db_config.j2_ из _ansible/templates_ в директорию _ansible/roles/app/templates/_. Файл _ansible/files/puma.service_ скопируем в _ansible/roles/app/files/_.

Опишем используемый хендлер в cоответствующей директории роли _app_

_ansible/roles/app/handlers/main.yml_:

```code
- name: reload puma
  systemd: name=puma state=restarted
```

Определяем переменную по умолчанию для адреса подключения к MongoDB в файле _ansible/roles/app/defaults/main.yml_:

```code
db_host: 127.0.0.1
```

#### вызов ролей

переписываем плейбук _ansible/app.yml_: заменим определение тасков и хендлеров на вызов роли:

```code
  - name: Configure App
    hosts: app
    become: true

    vars:
     db_host: 10.166.15.207

    roles:
    - app
    
    handlers:
    - name: reload puma
      systemd: name=puma state=restarted
```
Аналогичную операцию проделаем с файлом _ansible/db.yml_:

```code
  - name: Configure MongoDB
    hosts: db
    become: true

    vars:
      mongo_bind_ip: 0.0.0.0

    roles:
    - db
  
    handlers:
    - name: restart mongod
      service: name=mongod state=restarted
```

Для проверки роли пересоздадим инфраструктуру окружения stage, используя команды:

```bash
$ terraform destroy
$ terraform apply -auto-approve

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

Перед проверкой не забудьте изменить внешние IP адреса
инстансов в инвентори файле ansible/inventory и переменную
db_host в плейбуке app.yml:

```bash
$ ansible-playbook site.yml --check
$ ansible-playbook site.yml

PLAY RECAP *******************************************************************************************
appserver                  : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
dbserver                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Обычно инфраструктура состоит из нескольких окружений. Эти окружения могут иметь небольшие отличия в настройках инфраструктуры и конфигурации управляемых хостов.

С помощью Terraform мы уже описали инфраструктуру для тестового и боевого окружения (production).

Теперь используем Ansible для управления каждым из них.

Создадим директорию environments в директории _ansible_ для определения настроек окружения. В директории ansible/environments создадим две директории для наших окружений _stage_ и _prod_.

Так как мы управляем разными хостами на разных окружениях, то нам необходим свой инвентори-файл для каждого из окружений.

Скопируем инвентори файл ansible/inventory в каждую из директорий окружения environtents/prod и environments/stage.

Сам файл ansible/inventory при этом удалим.

Теперь, когда у нас два инвентори файла, то чтобы управлять хостами окружения нам необходимо явно передавать команде, какой инвентори мы хотим использовать.

Например, чтобы задеплоить приложение на prod окружении мы должны теперь написать:

```bash
$ ansible-playbook -i environments/prod/inventory deploy.yml
```

Таким образом сразу видно, с каким окружением мы работаем. В нашем случае, мы также определим окружение по умолчанию (stage), что упростит команду для тестового окружения.

Определим окружение по умолчанию в конфиге Ansible (файл _ansible/ansible.cfg_):

```code
[defaults]
inventory = ./environments/stage/inventory # Inventory по-умолчанию задается здесь
remote_user = appuser
private_key_file = ~/.ssh/appuser
host_key_checking = False
```

#### Переменные групп хостов 

Параметризация конфигурации ролей за счет переменных дает нам возможность изменять настройки конфигурации, задавая нужные значения переменных.

Ansible позволяет задавать переменные для групп хостов, определенных в инвентори файле. Воспользуемся этим для управления настройками окружений.

Директория group_vars, созданная в директории плейбука или инвентори файла, позволяет создавать файлы (имена, которых должны соответствовать названиям групп в инвентори файле) для определения переменных для группы хостов.

Создадим директорию group_vars в директориях наших окружений _environments/prod_ и _environments/stage_.

Зададим настройки окружения stage, используя групповые переменные:
- Создадим файлы stage/group_vars/app для определения переменных для группы хостов app, описанных в инвентори файле stage/inventory
- Скопируем в этот файл переменные, определенные в плейбуке ansible/app.yml.
- Также удалим определение переменных из самого плейбука ansible/app.yml.

Пример файла ansible/environments/stage/group_vars/app:

```code
db_host: 10.166.15.207
```

Аналогичным образом определим переменные для группы хостов БД на окружении stage:
- Создадим файл stage/group_vars/db и скопируем в него содержимое переменные из плейбука ansible/db.yml
- Секцию определения переменных из самого плейбука ansible/db.yml удалим.

Пример файла ansible/environments/stage/group_vars/db:

```code
mongo_bind_ip: 0.0.0.0
```

Как мы помним, по умолчанию Ansible создает группу all для всех хостов указанных в инвентори файле. Создадим файл с переменными для этой группы. Таким образом переменные в этом файле будут доступны всем хостам окружения.
Создайте файл ansible/environments/stage/group_vars/all со следующим содержимым:

```code
env: stage
```

Конфигурация окружения prod будет идентичной, за исключением переменной env, определенной для группы all.
- Для настройки окружения prod скопируйте файлы app, db, all из директории stage/group_vars в директорию prod/group_vars.
- В файле prod/group_vars/all измените значение env переменной на prod.

Должно получиться так:

```code
env: prod
```

Для хостов из каждого окружения мы определили переменную env, которая содержит название окружения. Теперь настроим вывод информации об окружении, с которым мы работаем, при применении плейбуков.

Определим переменную по умолчанию env в используемых ролях

Для роли app в файле ansible/roles/app/defaults/main.yml:

```code
# defaults file for app
db_host: 127.0.0.1
env: local
```

Для роли db в файле ansible/roles/db/defaults/main.yml:

```code
# defaults file for db
mongo_port: 27017
mongo_bind_ip: 127.0.0.1
env: local
```

Будем выводить информацию о том, в каком окружении
находится конфигурируемый хост. Воспользуемся модулем debug
для вывода значения переменной. Добавим следующий таск в
начало наших ролей.
Для роли app (файл ansible/roles/app/tasks/main.yml):

```code
# tasks file for app
- name: Show info about the env this host belongs to
debug:
msg: "This host is in {{ env }} environment!!!"
```

Добавим такой же таск в роль db (файл ansible/roles/db/tasks/main.yml):

```code
# tasks file for db
- name: Show info about the env this host belongs to
debug: msg="This host is in {{ env }} environment!!!"
```
Перенесем все плейбуки в отдельную директорию согласно best practices:
- Создадим директорию ansible/playbooks и перенесем туда все наши плейбуки, в том числе из прошлого ДЗ.
- В директории ansible у нас остались еще файлы из прошлых ДЗ, которые нам не особо нужны. Создадим директорию ansible/old и перенесем туда все, что не относится к текущей конфигурации.
- откорректировать ссылки на плейбуки сборки в файлах packer

улучшим наш ansible.cfg. Для этого приведем его к такому виду:

```code
[defaults]
inventory = ./environments/stage/inventory
remote_user = appuser
private_key_file = ~/.ssh/appuser
# Отключим проверку SSH Host-keys (поскольку они всегда разные для новых инстансов)
host_key_checking = False
# Отключим создание *.retry-файлов (они нечасто нужны, но мешаются под руками)
retry_files_enabled = False
# # Явно укажем расположение ролей (можно задать несколько путей через ; )
roles_path = ./roles
[diff]
# Включим обязательный вывод diff при наличии изменений и вывод 5 строк контекста
always = True
context = 5
```

Для проверки роли пересоздадим инфраструктуру окружения stage, используя команды:

```bash
$ terraform destroy
$ terraform apply -auto-approve

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

Перед проверкой не забудьте изменить внешние IP адреса инстансов в инвентори файле ansible/environments/stage/inventory и переменную db_host в stage/group_vars/app

```bash
$ ansible-playbook playbooks/site.yml --check
$ ansible-playbook playbooks/site.yml

PLAY RECAP *******************************************************************************************
appserver                  : ok=10   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
dbserver                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Для проверки настройки prod окружения сначала удалим инфраструктуру окружения stage. Затем поднимем инфраструктуру для prod окружения.
Перед проверкой не забудьте изменить внешние IP-адреса инстансов в инвентори файле ansible/environments/prod/inventory и переменную db_host в prod/group_vars/app

```bash
$ ansible-playbook -i environments/prod/inventory playbooks/site.yml --check
$ ansible-playbook -i environments/prod/inventory playbooks/site.yml
...
PLAY RECAP *******************************************************************************************
appserver                  : ok=10   changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
dbserver                   : ok=4    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### Работа с Community-ролями

коммьюнити-роли в основном находятся на портале Ansible Galaxy и работа с ними производится с помощью утилиты ansible-galaxy и файла requirements.yml

Используем роль jdauphant.nginx и настроим обратное проксирование для нашего приложения с помощью nginx

Хорошей практикой является разделение зависимостей ролей (requirements.yml) по окружениям.
1. Создадим файлы environments/stage/requirements.yml и environments/prod/requirements.yml
2. Добавим в них запись вида:

```code
- src: jdauphant.nginx
  version: v2.21.1
```

3. Установим роль:

```bash
$ ansible-galaxy install -r environments/stage/requirements.yml
```

4. Комьюнити-роли не стоит коммитить в свой репозиторий, для этого добавим в .gitignore запись: jdauphant.nginx

Рассмотрим [документацию роли](https://github.com/jdauphant/ansible-role-nginx).
Как мы видим, для минимальной настройки проксирования необходимо добавить следующие переменные в stage/group_vars/app и prod/group_vars/app
:

```code
nginx_sites:
  default:
    - listen 80
    - server_name "reddit"
    - location / {
      proxy_pass http://127.0.0.1:порт_приложения;
      }
```

Добавьте в конфигурацию Terraform открытие 80 порта для инстанса приложения. Добавьте вызов роли jdauphant.nginx в плейбук app.yml Примените плейбук site.yml для окружения stage и проверьте, что приложение теперь доступно на 80 порту

### Работа с Ansible Vault

Для безопасной работы с приватными данными (пароли, приватные ключи и т.д.) используется механизм . Данные сохраняются в зашифрованных файлах, которые при выполнении плейбука автоматически расшифровываются. Таким образом, приватные данные можно хранить в системе контроля версий.

Для шифрования используется мастер-пароль (aka vault key). Его нужно передавать команде ansible-playbook при запуске, либо указать файл с ключом в ansible.cfg. Не допускайте хранения этого ключ-файла в Git! Используйте для разных окружений разный vault key.

Подготовим плейбук для создания пользователей, пароль пользователей будем хранить в зашифрованном виде в файле credentials.yml:
1. Создайте файл vault.key со произвольной строкой ключа
2. Изменим файл ansible.cfg, добавим опцию
vault_password_file в секцию [defaults]

```code
[defaults]
...
vault_password_file = vault.key
```

❗ Обязательно добавьте в .gitignore файл vault.key. А еще лучше - храните его out-of-tree, аналогично ключам SSH (например, в папке ~/.ansible/vault.key)

Добавим плейбук для создания пользователей - файл
ansible/playbooks/users.yml:

```code
---
- name: Create users
  hosts: all
  become: true

  vars_files:
    - "{{ inventory_dir }}/credentials.yml"

  tasks:
    - name: create users
      user:
        name: "{{ item.key }}"
        password: "{{ item.value.password|password_hash('sha512', 65534|random(seed=inventory_hostname)|string) }}"
        groups: "{{ item.value.groups | default(omit) }}"
      with_dict: "{{ credentials.users }}"
```

Создадим файл с данными пользователей для каждого окружения 

Файл для prod (ansible/environments/prod/credentials.yml):

```code
---
credentials:
  users:
    admin:
      password: admin123
      groups: sudo
```

Файл для stage (ansible/environments/stage/credentials.yml):

```code
---
credentials:
  users:
    admin:
      password: qwerty123
      groups: sudo
    qauser:
      password: test123
```

Зашифруем файлы используя vault.key (используем одинаковый для всех окружений):

```bash
$ ansible-vault encrypt environments/prod/credentials.yml
$ ansible-vault encrypt environments/stage/credentials.yml
```

Проверьте содержимое файлов, убедитесь что они зашифрованы

Добавьте вызов плейбука в файл site.yml и выполните его
для stage окружения:

```bash
$ ansible-playbook playbooks/site.yml --check
$ ansible-playbook playbooks/site.yml
```

>>>>>>> ansible-3

**_все работы выполнены в окружении stage_**

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
      mongo_bind_ip: 0.0.0.0 # <-- Переменная задается в блоке vars
    tasks: 
      - name: change mongo config file
        become: true 
        template:
          src: templates/mongod.conf.j2 
          dest: /etc/mongod.conf 
          mode: 0644
        tags: db-tag
```

Повторяем проверку плейбука:

```bash
$ ansible-playbook reddit_app.yml --check --limit db

PLAY [Configure hosts & deploy application] **********************************************************

TASK [Gathering Facts] *******************************************************************************
...
ok: [dbserver]

TASK [change mongo config file] **********************************************************************
changed: [dbserver]

PLAY RECAP *******************************************************************************************
dbserver                   : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Теперь проверка должна пройти успешно. Пробный прогон показывает нам, что таск с описанием "Change mongo config file" изменит свое состояние для хоста dbserver, что означает, что на этом хосте произойдут изменения относительно его текущего состояния.

Handlers похожи на таски, однако запускаются только по оповещению от других задач. Таск шлет оповещение handler-у в случае, когда он меняет свое состояние. По этой причине handlers удобно использовать для перезапуска сервисов. Это, например, позволяет перезапускать сервис, только в случае если поменялся его конфиг-файл.

Изменение конфигурационного файла MongoDВ требует от нас перезапуска БД для применения конфигурации. Используем для этой задачи handler. Определим handler для рестарта БД и добавим вызов handler-а в созданный нами таск.

Файл ansible/reddit_app.yml:

```code
---
  - name: Configure hosts & deploy application 
    hosts: all 
    vars:
      mongo_bind_ip: 0.0.0.0
    tasks: 
    - name: change mongo config file
      become: true 
      template:
        src: templates/mongod.conf.j2 
        dest: /etc/mongod.conf 
        mode: 0644
      tags: db-tag
    handlers:: # <-- Добавим блок handlers и задачу
    - name: restart mongod
      become: true
      service: name=mongod state=restarted
```

Для начала сделаем пробный прогон, и убедимся, что нет ошибок:

```bash
$  ansible-playbook reddit_app.yml --check --limit db
...
PLAY RECAP *******************************************************************************************
dbserver                   : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Применяем плейбук:

```bash
$  ansible-playbook reddit_app.yml --check --limit db

PLAY [Configure hosts & deploy application] **********************************************************

TASK [Gathering Facts] *******************************************************************************
[DEPRECATION WARNING]: Distribution Ubuntu 16.04 on host dbserver should use /usr/bin/python3, but is
 using /usr/bin/python for backward compatibility with prior Ansible releases. A future Ansible 
release will default to using the discovered platform python for this host. See 
https://docs.ansible.com/ansible/2.9/reference_appendices/interpreter_discovery.html for more 
information. This feature will be removed in version 2.12. Deprecation warnings can be disabled by 
setting deprecation_warnings=False in ansible.cfg.
ok: [dbserver]

TASK [change mongo config file] **********************************************************************
changed: [dbserver]

PLAY RECAP *******************************************************************************************
dbserver                   : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

shaad@shaad-mobile:~/otus-devops/shaadowsky_infra/ansible$ ansible-playbook reddit_app.yml  --limit db

PLAY [Configure hosts & deploy application] **********************************************************

TASK [Gathering Facts] *******************************************************************************
...
ok: [dbserver]

TASK [change mongo config file] **********************************************************************
changed: [dbserver]

PLAY RECAP *******************************************************************************************
dbserver                   : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

#### настройка инстанса приложения

Вспомним, как на предыдущих занятиях мы уже копировали unit-файл для сервера Puma, чтобы управлять сервисом и добавить его в автостарт. Теперь скопируем unit-файл на инстанс приложения, используя Ansible.
Создайте директорию files внутри директории ansible и добавьте туда файл puma.service. 

```code
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
EnvironmentFile=/home/appuser/db_config
User=appuser
WorkingDirectory=/home/appuser/reddit
ExecStart=/bin/bash -lc 'puma'
Restart=always

[Install]
WantedBy=multi-user.target
```

Через переменную окружения EnvironmentFile передается адрес инстанса БД, чтобы приложение знало куда ему обращаться для хранения данных.

Добавим в наш сценарий таск для копирования unit-файла на хост приложения. Для копирования простого файла на удаленный хост, используем модуль copy, а для настройки автостарта Puma-сервера используем модуль systemd. 

```code
---
  - name: Configure hosts & deploy application 
...
  - name: Add unit file for Puma
    become: true
    copy:
      src: files/puma.service
      dsdt: /etc/systemd/system/puma.service
    tags: app-tag
    notify: reload puma
  
  - name: enable Puma
    become: true
    systemd: name=puma enabled=yes
```

Не забудем добавить новый handler в каждый name, который укажет systemd, что unit для сервиса изменился и его следует перечитать:

```code
handlers:
  - name: restart mongod
    become: true
    service: name=mongod state=restarted

  - name: reload puma
    become: true
    systemd: name=puma state=restarted
```

Создаем шаблон в директории templates/db_config.j2 куда добавим следующую строку:

```code
DATABASE_URL={{ db_host }
```

Как видим, данный шаблон содержит присвоение переменной DATABASE_URL значения, которое мы передаем через Ansible переменную db_host.

Добавим таск для копирования созданного шаблона:

```code
  - name: Add unit file for Puma
...
  - name: Add config for DB connection
    template:
      src: templates/db_config.j2
      dest: /home/appuser/db_config
    tags: app-tag

  - name: enable puma
    become: true
    systemd: name=puma enabled=yes
    tags: app-tag
```

И определяем переменную:

```code
---
  - name: Configure hosts & deploy application 
    hosts: all 
    vars:
      mongo_bind_ip: 0.0.0.0
      db_host: 10.166.15.199 # <-- подставьте сюда ваш IP
    tasks: 
```

Переменной db_host присваиваем значение внутреннего IP-адреса  инстанса базы данных. Этот адрес можно посмотреть в консоли GCP, используя terraform show или команду gcloud.

Проверяем и применяем:

```bash
$ ansible-playbook reddit_app.yml --check --limit app --tags app-tag
$ ansible-playbook reddit_app.yml --limit app --tags app-tag
...
PLAY RECAP *******************************************************************************************
appserver                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

### Деплой (deploy)

Добавим еще несколько тасков в сценарий нашего плейбука. Используем модули git и bundle для клонирования последней версии кода нашего приложения и установки зависимых Ruby Gems через bundle.

```code
  tasks:
...
    - name: Fetch the latest version of application code
      git:
        repo: 'https://github.com/express42/reddit.git'
        dest: /home/appuser/reddit
        version: monolith # <-- Указываем нужную ветку
      tags: deploy-tag
      notify: reload puma

    - name: Bundle install
      bundler:
        state: present
        chdir: /home/appuser/reddit # <-- В какой директории выполнить команду bundle
        tags: deploy-tag
```

Проверяем и раскатываем:

```
$ ansible-playbook reddit_app.yml --check --limit app --tags deploy-tag

$ ansible-playbook reddit_app.yml --limit app --tags deploy-tag

PLAY [Configure hosts & deploy application] **********************************************************

TASK [Gathering Facts] *******************************************************************************
ok: [appserver]

TASK [Fetch the latest version of application code] **************************************************
changed: [appserver]

RUNNING HANDLER [reload puma] ************************************************************************
changed: [appserver]

PLAY RECAP *******************************************************************************************
appserver                  : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

*_NOTE_* почему-то не работало без become: true

### Несколько плейбуков

В предыдущей части мы создали один плейбук, в котором определили один сценарий (play) и, как помним, для запуска нужных тасков на заданной группе хостов мы использовали опцию --limit для указания группы хостов и --tags для указания нужных тасков.

Очевидна проблема такого подхода, которая состоит в том, что мы должны помнить при каждом запуске плейбука, на каком хосте какие таски мы хотим применить, и передавать это в опциях командной строки.

Давайте попробуем разбить наш сценарий на несколько и посмотрим, как это изменит ситуацию.

Создадим новый файл reddit_app2.yml в директории ansible. Определим в нем несколько сценариев (plays), в которые объединим задачи, относящиеся к используемым в плейбуке тегам.

Определим отдельный сценарий для управления конфигурацией MongoDB. Будем при этом использовать уже имеющиеся наработки из reddit_app.yml плейбука.a

Скопируем определение сценария из reddit_app.yml и всю информацию, относящуюся к настройке MongoDB, которая будет включать в себя таски, хендлеры и переменные. Помним, что таски для настройки MongoDB приложения мы помечали тегом db-tag.

```code
# Данный сценарий мы составляем только для MongoDB, может стоит поменять описание?
- name: Configure hosts & deploy application
# Применять сценарий мы хотим только к серверам группы db или ко всем?
  hosts: all
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: Change mongo config file
      become: true
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      tags: db-tag # <-- нужен ли нам здесь тег?
      notify: restart mongod

  handlers:
    - name: restart mongod
      become: true
      service: name=mongod state=restarted
```

- Изменим словесное описание:
- Укажем нужную группу хостов
- Уберем теги из тасков и определим тег на уровне сценария, чтобы мы могли запускать сценарий, используя тег.

Отметим, что все наши таски требуют выполнения из-под пользователя root, поэтому нет смысла их указывать для каждого task.
- Вынесем become: true на уровень сценария.

```code
---
- name: Configure MongoDB
  hosts: db
  tags: db-tag
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: Change mongo config file
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      notify: restart mongod

  handlers:
  - name: restart mongod
    service: name=mongod state=restarted
```

Аналогичным образом определим еще один сценарий для настройки инстанса приложения. Скопируем еще раз определение сценария из reddit_app.yml и всю информацию относящуюся к настройке инстанса приложения, которая будет включать в себя таски, хендлеры и переменные. Помним, что таски для настройки инстанса приложения мы помечали тегом app-tag. Вставим скопированную информацию в reddit_app2.yml следом за сценарием для MongoDB.

```code
---
  - name: Configure MongoDB
...
  - name: Configure App
    hosts: all
    vars:
     db_host: 10.166.15.203
    tasks:
      - name: Add unit file for Puma
        become: true
        copy:
          src: files/puma.service
          dest: /etc/systemd/system/puma.service
        tags: app-tag
        notify: reload puma
  
      - name: Add config for DB connection
        template:
          src: templates/db_config.j2
          dest: /home/appuser/db_config
        tags: app-tag
  
      - name: enable puma
        become: true
        systemd: name=puma enabled=yes
        tags: app-tag
  
    handlers:
    - name: reload puma
      become: true
      systemd: name=puma state=restarted
```

теперь напишем сценарий для App.

- Изменим словесное описание
- Укажем нужную группу хостов
- Уберем теги из тасков и определим тег на уровне сценария,  чтобы мы запускать сценарий, используя тег.
- Также заметим, что большинство из наших тасков требуют выполнения из-под пользователя root, поэтому вынесем become: true на уровень сценария.
- В таске, который копирует конфиг-файл в домашнюю директорию пользователя appuser, явно укажем пользователя и владельца файла.

```code
  - name: Configure App
    hosts: app
    tags: app-tag
    become: true
    vars:
     db_host: 10.166.15.203
    tasks:
      - name: Add unit file for Puma
        copy:
          src: files/puma.service
          dest: /etc/systemd/system/puma.service
        notify: reload puma
  
      - name: Add config for DB connection
        template:
          src: templates/db_config.j2
          dest: /home/appuser/db_config
          owner: appuser
          group: appuser
  
      - name: enable puma
        systemd: name=puma enabled=yes
  
    handlers:
    - name: reload puma
      systemd: name=puma state=restarted
```

Для чистоты эксперимента переподнимает окружение, исправляем адреса серверов в инвентори и проверяем:

```bash
$ ansible-playbook reddit_app2.yml --tags db-tag --check

$ ansible-playbook reddit_app2.yml --tags db-tag

PLAY RECAP *******************************************************************************************
dbserver                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Обратите внимание, что теперь при вызове команд нам не нужно указывать явно, на каких хостах запускать плейбук. При запуске команды мы указываем тег, который ссылается на конкретный сценарий.

```bash
$ ansible-playbook reddit_app2.yml --tags app-tag --check
$ ansible-playbook reddit_app2.yml --tags app-tag
...
PLAY RECAP *******************************************************************************************
appserver                  : ok=5    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Далее добавляем сценарий деплоя.

```code
  - name: Deploy App
    hosts: app
    tags: deploy-tag
    tasks:
      - name: Fetch the latest version of application code
        git:
          repo: 'https://github.com/express42/reddit.git'
          dest: /home/appuser/reddit
          version: monolith
        notify: restart puma
  
      - name: bundle install
        bundler:
          state: present
          chdir: /home/appuser/reddit
  
    handlers:
    - name: restart puma
      become: true
      systemd: name=puma state=restarted
```

проверяем:

```bash
$ ansible-playbook reddit_app2.yml --tags deploy-tag --check

$ ansible-playbook reddit_app2.yml --tags deploy-tag

PLAY RECAP *******************************************************************************************
appserver                  : ok=4    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

### Несколько плейбуков

Описав несколько сценариев для управления конфигурацией инстансов и деплоя приложения, управлять хостами стало немного легче.

Теперь, для того чтобы применить нужную часть конфигурационного кода (сценарий) к нужной группе хостов достаточно лишь указать ссылку на эту часть кода, используя тег.

Однако, есть проблема: с ростом числа управляемых сервисов, будет расти количество различных сценариев и, как результат, увеличится объем плейбука.

Это приведет к тому, что в плейбуке, будет сложно разобраться. Поэтому, следующим шагом попытаемся разделить наш плейбук на несколько.

В директории ansible создадим три новых файла: app.yml, db.yml и deploy.yml. Заодно переименуем наши предыдущие плейбуки:
- reddit_app.yml ➡ reddit_app_one_play.yml
- reddit_app2.yml ➡ reddit_app_multiple_plays.yml

Из файла reddit_app_multiple_plays.yml скопируем сценарий, относящийся к настройке БД, в файл db.yml. При этом, удалим тег определенный в сценарии. Поскольку мы выносим наши сценарии в отдельные плейбуки, то для запуска нужного нам сценария достаточно будет указать имя плейбука, который его содержит. Значит, тег нам больше не понадобится.

```code
---
  - name: Configure MongoDB
    hosts: db
    become: true
    vars:
      mongo_bind_ip: 0.0.0.0
    tasks:
      - name: Change mongo config file
        template:
          src: templates/mongod.conf.j2
          dest: /etc/mongod.conf
          mode: 0644
        notify: restart mongod
  
    handlers:
    - name: restart mongod
      service: name=mongod state=restarted
```

Аналогично вынесем настройку хоста приложения из reddit_app_multiple_plays.yml в отдельный плейбук app.yml. Не забудем удалить тег, т.к. в нем теперь у нас нет необходимости.

```code
---
  - name: Configure App
    hosts: app
    become: true
    vars:
     db_host: 10.166.15.205
    tasks:
      - name: Add unit file for Puma
        copy:
          src: files/puma.service
          dest: /etc/systemd/system/puma.service
        notify: reload puma
  
      - name: Add config for DB connection
        template:
          src: templates/db_config.j2
          dest: /home/appuser/db_config
          owner: appuser
          group: appuser
  
      - name: enable puma
        systemd: name=puma enabled=yes
  
    handlers:
    - name: reload puma
      systemd: name=puma state=restarted
```

Аналогично вынесем настройку деплоя приложения из reddit_app_multiple_plays.yml в отдельный плейбук deploy.yml. Не забудем удалить тег, т.к. в нем теперь у нас нет необходимости.

```code
- name: Deploy App
  hosts: app
  tasks:
    - name: Fetch the latest version of application code
      git:
        repo: 'https://github.com/express42/reddit.git'
        dest: /home/appuser/reddit
        version: monolith
      notify: restart puma

    - name: bundle install
      bundler:
        state: present
        chdir: /home/appuser/reddit

  handlers:
  - name: restart puma
    become: true
    systemd: name=puma state=restarted
```

Создадим файл site.yml в директории ansible, в котором опишем управление конфигурацией всей нашей инфраструктуры. Это будет нашим главным плейбуком, который будет включать в себя все остальные:

```code
---
- import_playbook: db.yml
- import_playbook: app.yml
- import_playbook: deploy.yml
```

Переподнимает окружение stage, изменяем внешние IP-адреса инстансов и переменную db_host в плейбуке app.yml

```bash
$ terraform destroy
$ terraform apply -auto-approve=false
$ ansible-playbook site.yml --check
$ ansible-playbook site.yml
...
PLAY RECAP *******************************************************************************************
appserver                  : ok=9    changed=7    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
dbserver                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

## Провиженинг в Packer

В данной части мы изменим provision в Packer и заменим bashскрипты на Ansible-плейбуки. Мы уже создали плейбуки для конфигурации и деплоя приложения. Создадим теперь на их основе плейбуки ansible/packer_app.yml и ansible/packer_db.yml. Каждый из них должен реализовывать функционал bashскриптов, которые использовались в Packer ранее.
- packer_app.yml - устанавливает Ruby и Bundler
- packer_db.yml - добавляет репозиторий MongoDB, устанавливает ее и включает сервис.

Заменим секцию Provision в образе packer/app.json на Ansible:

```code
  "provisioners": [
    {
      "type": "ansible",
      "playbook_file": "ansible/packer_app.yml"
    }
  ]
```

Такие же изменения выполним и для packer/db.json:

```code
  "provisioners": [
    {
      "type": "ansible",
      "script": "ansible/packer_db.yml"
    }
  ]
```




```code
```
```code
```
```code
```
```code
```
```code
```
```code
```
```code
```
