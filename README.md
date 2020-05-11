# shaadowsky_infra

## hw-11 Ansible-4

## Разработка и тестирование Ansible ролей и плейбуков

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

### локальная разработка на Vagrant

установить vagrant

```code
$ vagrant -v
Vagrant 2.2.6
```

Описание характеристик VMs, которые мы хотим
создать, должно содержаться в файле с
названием Vagrantfile.
Мы создадим инфраструктуру, которую мы
создавали до этого в GCE при помощи Terraform,
на своей локальной машине, используя Vagrant.

Перед началом работы с Vagrant добавим следующие
строки в наш .gitignore файл, чтобы не комитить
информацию о создаваемых Vagrant машинах и логах

```code
... <- предыдущие записи
# Vagrant & molecule
.vagrant/
*.log
*.pyc
.molecule
.cache
.pytest_cache
```

Создаём в директории _ansible_ файл Vagrantfile c определением двух ВМ:

```code
Vagrant.configure("2") do |config|

  config.vm.provider :virtualbox do |v|
    v.memory = 512
  end

  config.vm.define "dbserver" do |db|
    db.vm.box = "ubuntu/xenial64"
    db.vm.hostname = "dbserver"
    db.vm.network :private_network, ip: "10.10.10.10"
  end
  
  config.vm.define "appserver" do |app|
    app.vm.box = "ubuntu/xenial64"
    app.vm.hostname = "appserver"
    app.vm.network :private_network, ip: "10.10.10.20"
  end
end
```

подъём стенда выполняется командой _vagrant up_

Vagrant поддерживает большое количество провижинеров, которые позволяют автоматизировать процесс конфигурации созданных VMs с использованием популярных инструментов управления конфигурацией и обычных скриптов на bash. Мы будем использовать Ansible провижинер для проверки работы наших ролей и плейбуков.

Добавляем провижининг в определение хоста dbserver:

```code
  config.vm.define "dbserver" do |db|
...
    db.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
      "db" => ["dbserver"],
      "db:vars" => {"mongo_bind_ip" => "0.0.0.0"}
      }
    end
  end
  ...
  ```

Провижининг происходит автоматически при запуске новой машины. Если же мы хотим применить провижининг на уже запущенной машине, то необходимо использовать команду provision. Если мы хотим применить команду для конкретного хоста, то нам также нужно передать его имя в качестве аргумента.

(Тут расходится текущее состояние (2020-05-07) базового образа убунуту 1604  и его состояние на момент подготовки презы и надо поставить питон2.7). 

Добавляем плейбук base.yml, устанавливающий python2.7 и добавим его в site.yml. Таким образом, он будет выполняться для всез зостов в начале выполнения.  Используем raw модуль, который позволяет запускать команды по SSH и не требует наличия python на управляемом хосте. Отменим также сбор фактов ансиблом, т.к. данный процесс требует установленного python и выполняется перед началом применения конфигурации

```code
---
- name: Check && install python
  hosts: all
  become: true
  gather_facts: False

  tasks:
    - name: Install python for Ansible
      raw: test -e /usr/bin/python || (apt -y update && apt install -y python-minimal)
      changed_when: False
```

Также удалим плейбук users.yml из site.yml.

```code
---
  - import_playbook: base.yml
  - import_playbook: db.yml
  - import_playbook: app.yml
  - import_playbook: deploy.yml
```

Повторим попытку провижининга хоста dbserver:

```bash
$ vagrant provision dbserver
...
PLAY [Check && install python] *************************************************

TASK [Install python for Ansible] **********************************************
ok: [dbserver]

PLAY [Configure MongoDB] *******************************************************

TASK [Gathering Facts] *********************************************************
ok: [dbserver]

...
PLAY RECAP *********************************************************************
dbserver                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Изменим роль db, добавив файл тасков db/tasks/install_mongo.yml для установки MongoDB. Добавим к каждому таску тег install, пометив его как шаг установки

Скопируйте таски из файла packer_db.yml и вставьте их в файл db/tasks/install_mongo.yml

Поскольку наши роли начинают включать в себя все больше тасков, то мы начинаем группировать их по разным файлам. Мы уже вынесли таски установки MongoDB в отдельный файл роли, аналогично поступим для тасков управления конфигурацией. 

Вынесем таски управления конфигом монги в отдельный файл config_mongo.yml.

В файле main.yml роли будем вызывать таски в нужном нам порядке:

```code
---
# tasks file for db

- name: Show info about the env this host belongs to
  debug:
    msg: "This host is in {{ env }} environment!!!"

- include: install_mongo.yml
- include: config_mongo.yml
```

Применим роль для локальной машины dbserver:

```bash
$ vagrant provision dbserver
...
PLAY RECAP *********************************************************************
dbserver                   : ok=9    changed=5    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

Видим, что провижининг выполнился успешно. Проверим
доступность порта монги для хоста appserver, используя
команду telnet:

```bash
$ vagrant ssh appserver
Welcome to Ubuntu 16.04.3 LTS (GNU/Linux 4.4.0-96-generic x86_64)
Last login: Tue Sep 26 14:13:40 2017 from 10.0.2.2
ubuntu@appserver:~$ telnet 10.10.10.10 27017
Trying 10.10.10.10...
Connected to 10.10.10.10.
Escape character is '^]'.
```

Подключение удалось, значит порт доступен для хоста appserver и конфигурация роли верна.

Аналогично роли db мы включим в нашу роль app конфигурацию из packer_app.yml плейбука, необходимую для настройки хоста приложения. Создадим новый файл для тасков ruby.yml внутри роли app и скопируем в него таски из плейбука packer_app.yml

```code
---
- name: Install ruby and rubygems and required packages
  apt: "name={{ item }} state=present"
  with_items:
    - ruby-full
    - ruby-bundler
    - build-essential
  tags: ruby
  ```

Вынесем настройки puma сервера также в отдельный файл для тасков в рамках роли. Создадим файл app/tasks/puma.yml и скопируем в него таски из app/tasks/main.yml, относящиеся к настройке Puma сервера и запуску приложения.

```code
---
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

В файле main.yml роли будем вызывать таски в нужном нам порядке:

```code
---
# tasks file for app

- name: Show info about the env this host belongs to
  debug:
    msg: "This host is in {{ env }} environment!!!"

- include: ruby.yml
- include: puma.yml
```

Аналогично dbserver определим Ansible провижинер для хоста appserver в Vagrantfile:

```code
Vagrant.configure("2") do |config|
...
  config.vm.define "appserver" do |app|
    app.vm.box = "ubuntu/xenial64"
    app.vm.hostname = "appserver"
    app.vm.network :private_network, ip: "10.10.10.20"

    app.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
      "app" => ["appserver"],
      "app:vars" => { "db_host" => "10.10.10.10"}
      }
    end
  end
end
```

Директива ansible.groups динамически генерирует инвентори для проивженинга в соответствии с конфигурацией, описанной в вагрантфайле. То есть у нас будет создаваться группа [app], в которой будет один хост appserver (что соответсвует создаваемой VM). Далее мы определяем переменные для данной группы app.

Можно посмотреть, какой инвентори файл Vagrant сгенерировал при провижининге dbserver.

```bash
$ cat .vagrant/provisioners/ansible/inventory/vagrant_ansible_inventory
# Generated by Vagrant

dbserver ansible_host=127.0.0.1 ansible_port=2222 ansible_user='vagrant' ansible_ssh_private_key_file='/home/shaad/DevOps/shaadowsky_infra/ansible/.vagrant/machines/dbserver/virtualbox/private_key'

[db]
dbserver

[db:vars]
mongo_bind_ip=0.0.0.0
```

ПРоверяем:

```bash
$ vup
...
TASK [app : Add config for DB connection] **************************************
fatal: [appserver]: FAILED! => {"changed": false, "checksum": "dfbe4b5cf3ec32d91d20045e2ee7f7b26c60ef34", "msg": "Destination directory /home/appuser does not exist"}

RUNNING HANDLER [app : reload puma] ********************************************

PLAY RECAP *********************************************************************
appserver                  : ok=6    changed=2    unreachable=0    failed=1    skipped=0    rescued=0    ignored=0   

Ansible failed to complete successfully. Any error output should be
visible above. Please fix these errors and try again.
```

Ansible не удалось создать файл с настройками подключения
к БД, потому что данный файл он пытается создать в домашней
директории пользователя appuser, которого у нас нет.
У нас есть два варианта решения проблемы: 1) создать
пользователя, как часть роли; 2) параметризировать нашу
конфигурацию, чтобы мы могли использовать ее для
пользователя другого, чем appuser.
Мы пойдем по второму пути. 

В нашей роли мы захардкодили пути установки конфигов и
деплоя приложения в домашнюю директорию пользователя
appuser. Параметризуем имя пользователя, чтобы дать
возможность использовать роль для иного пользователя.
Определим переменную по умолчанию внутри нашей роли:

```ansible/roles/app/defaults/main.yml
---
# defaults file for app
db_host: 127.0.0.1
env: local
deploy_user: appuser
```

Рассмотрим таски, определенные в файле
puma.yml. Первым делом, заменим модуль для
копирования unit файла с copy на template, чтобы
иметь возможность параметризировать unit файл:

```app/tasks/puma.yml 
---
  - name: Add unit file for Puma
    template:
      src: puma.service.j2
      dest: /etc/systemd/system/puma.service
    notify: reload puma
```

Далее параметризуем сам unit файл. Переместим
его из директории app/files в директорию app/
templates, т.к. мы поменяли используемый для
копирования модуль и добавим к файлу
puma.service расширение .j2, чтобы обозначить
данный файл как шаблон.
Заменим в созданном шаблоне все упоминания
appuser на переменную deploy_user:

```app/templates/puma.service.j2
[Unit]
Description=Puma HTTP Server
After=network.target

[Service]
Type=simple
EnvironmentFile=/home/{{ deploy_user }}/db_config
User={{ deploy_user }}
WorkingDirectory=/home/{{ deploy_user }}/reddit
ExecStart=/bin/bash -lc 'puma'
Restart=always

[Install]
WantedBy=multi-user.target
```

Снова обратимся к app/tasks/puma.yml и параметризуем оставшуюся
конфигурацию:

```app/tasks/puma.yml
---
  - name: Add unit file for Puma
    template:
      src: puma.service.j2
      dest: /etc/systemd/system/puma.service
    notify: reload puma
  
  - name: Add config for DB connection
    template:
      src: db_config.j2
      dest: "/home/{{ deploy_user }}/db_config"
      owner: "{{ deploy_user }}"
      group: "{{ deploy_user }}"
  
  - name: enable puma
    systemd: name=puma enabled=yes
```

Для провижининга хоста appserver мы
использовали плейбук site.yml.
Данный плейбук, помимо плейбука app.yml,
также вызывает плейбук ansible/playbooks/
deploy.yml, который применяется для группы
хостов app и который нам тоже нужно не забыть
параметризировать

```ansible/playbooks/deploy.yml
- name: Deploy App
  hosts: app
  vars:
    deploy_user: appuser

  tasks:
    - name: Fetch the latest version of application code
      git:
        repo: 'https://github.com/express42/reddit.git'
        dest: "/home/{{ deploy_user }}/reddit"
        version: monolith
      notify: restart puma

    - name: bundle install
      bundler:
        state: present
        chdir: "/home/{{ deploy_user }}/reddit"

  handlers:
  - name: restart puma
    become: true
    systemd: name=puma state=restarted
```

Мы ввели дополнительную переменную для
пользователя, запускающего приложение и
параметризировали нашу конфигурацию. Теперь
при вызове плейбуков для appserver
переопределим дефолтное значение переменной
пользователя на имя пользователя используемое
нашим боксом по умолчанию, т.е. ubuntu.
Используем при этом переменные extra_vars,
имеющие самый высокий приоритет по
сравнению со всеми остальными.

Добавим extra_vars переменные в блок определения
провижинера в Vagrantfile

```ansible/Vagrantfile
  config.vm.define "appserver" do |app|
    app.vm.box = "ubuntu/xenial64"
    app.vm.hostname = "appserver"
    app.vm.network :private_network, ip: "10.10.10.20"

    app.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
        "app" => ["appserver"],
        "app:vars" => { "db_host" => "10.10.10.10"}
      }
      ansible.extra_vars = {
        "deploy_user" => "vagrant"
      }
    end
  end
end
```

Проверяем:

```bash
$ vagrant provision appserver
==> appserver: Running provisioner: ansible...
TASK [Fetch the latest version of application code] ****************************
changed: [appserver]
TASK [bundle install] **********************************************************
changed: [appserver]
RUNNING HANDLER [restart puma] *************************************************
changed: [appserver]
PLAY RECAP *********************************************************************
appserver : ok=11 changed=5 unreachable=0 failed=0 
```

Выполните в директории ansible команду по удалению созданных машин _vagrant destroy -f_

Теперь создадим окружение и проверим что все корректно настроится и задеплоится _vagrant up_

Проверьте отсутсвие ошибок и что приложение корректно работает. Удалите окружение _vagrant destroy -f_

### Установка зависимостей

Для локального тестирования Ansible ролей будем использовать Molecule для создания машин и проверки конфигурации и Testinfra для написания тестов. Сначала установим все необходимые компоненты для тестирования: Molecule, Ansible, Testinfra на локальную машину используя pip. Установку данных модулей рекомендуется выполнять в созданной через virtualenv среде работы с питоном. Инструкции по установке virtualenv и virtualenvwrapper можно посмотреть [здесь](http://docs.python-guide.org/en/latest/dev/virtualenvs/). 

Добавьте в файл requirements.txt в директории ansible
следующие записи:

```ansible/requirements.txt
ansible>=2.4
molecule>=2.6
testinfra>=1.10
python-vagrant>=0.5.15
```

```bash
$ pip install -r requirements.txt
$ molecule --version 
molecule 3.0.2.1
   ansible==2.9.7 python==2.7
$ pip install -r requirements.txt
$ ansible --version
ansible 2.9.7
```

По умолчанию molecule не умеет работать с vagrant, не обходимо поставить плагин:

```bash
$ $ pip install molecule-vagrant
...
Installing collected packages: distro, selinux, molecule-vagrant
Successfully installed distro-1.5.0 molecule-vagrant-0.2 selinux-0.2.1
```

Используем команду molecule init для создания заготовки тестов для роли db. Выполнитекоманду ниже в директории с ролью nsible/roles/db:

```bash
$ molecule init scenario default -r db -d vagrant
--> Initializing new scenario default...
Initialized scenario in /home/shaad/DevOps/shaadowsky_infra/ansible/roles/db/molecule/default successfully.
```

Добавим несколько тестов, используя модули Testinfra, для проверки конфигурации, настраиваемой ролью db:

```db/molecule/default/tests/test_default.py
import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')

# check if MongoDB is enabled and running
def test_mongo_running_and_enabled(host):
    mongo = host.service("mongod")
    assert mongo.is_running
    assert mongo.is_enabled

# check if configuration file contains the required line
def test_config_file(host):
    config_file = host.file('/etc/mongod.conf')
    assert config_file.contains('bindIp: 0.0.0.0')
    assert config_file.is_file
```

Описание тестовой машины, которая создается Molecule для тестов содержится в файле db/molecule/default/molecule.yml

```code
---
dependency:
  name: galaxy
driver:
  name: vagrant
  provider:
    name: virtualbox
lint: yamllint
platforms:
  - name: instance
    box: ubuntu/xenial64
provisioner:
  name: ansible
  lint: ansible-lint
verifier:
  name: ansible
```

Создадим VM для проверки роли. В директории ansible/roles/db выполните команду:

```bash
$ molecule create
--> Test matrix
...    
    PLAY RECAP *********************************************************************
    instance                   : ok=1    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Посмотрим список созданных инстансов, которыми управляет
Molecule:

```bash
$ molecule list 
Instance Name    Driver Name    Provisioner Name    Scenario Name    Created    Converged
---------------  -------------  ------------------  ---------------  ---------  -----------
instance         vagrant        ansible             default          true       false
```

Также можем при необходимости дебага
подключиться по SSH внутрь VM:

```bash
$  molecule login -h instance
Warning: Permanently added '[127.0.0.1]:2222' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 16.04.6 LTS (GNU/Linux 4.4.0-178-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage


0 packages can be updated.
0 updates are security updates.

New release '18.04.4 LTS' available.
Run 'do-release-upgrade' to upgrade to it.


Last login: Mon May 11 04:34:20 2020 from 10.0.2.2
vagrant@instance:~$ exit
logout
Connection to 127.0.0.1 closed.
```

Molecule init генерирует плейбук для применения нашей роли. Данный плейбук можно посмотреть по пути db/molecule/default/converge.yml.

Поскольку таски нашей роли требуют выполнения из-под суперпользователя, то добавим become в определение сценария этого плейбука.

Дополнительно зададим еще переменную mongo_bind_ip.

```code
---
- name: Converge
  become: true
  hosts: all
  vars:
    mongo_bind_ip: 0.0.0.0
  roles:
    - role: db
```

Применим playbook.yml, в котором вызывается наша роль к
созданному хосту:

```bash
$ molecule converge
--> Test matrix
...
    PLAY RECAP *********************************************************************
    instance                   : ok=8    changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Прогоним тесты:

```bash
$  molecule verify 
--> Test matrix
...
    PLAY RECAP *********************************************************************
    instance                   : ok=2    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
    
Verifier completed successfully.
```

