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


