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

Провижининг происходит автоматически при запуске новой машины. Если же мы хотим применить провижининг на уже запущенной машине, то необходимо использовать команду
provision.
Если мы хотим применить команду для конкретного хоста, то нам также нужно передать его имя в качестве аргумента.

(Тут расходидится текущее состояние (2020-05-07) базового образа убунуту 1604  и его состояние на момент подготовки презы и надо поставить питон2.7). 

Добавляем плейбук base.yml, устанавливающий python2.7 и добавим его в site.yml. Таким образом, он будет выполняться для всез зостов в начале выполнения.  Используем raw модуль, который позволяет запускать команды по
SSH и не требует наличия python на управляемом хосте. Отменим
также сбор фактов ансиблом, т.к. данный процесс требует
установленного python и выполняется перед началом применения
конфигурации

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

Изменим роль db, добавив файл тасков db/tasks/
install_mongo.yml для установки MongoDB.
Добавим к каждому таску тег install, пометив его
как шаг установки

Скопируйте таски из файла packer_db.yml и вставьте их в файл db/tasks/
install_mongo.yml

Поскольку наши роли начинают включать в себя
все больше тасков, то мы начинаем группировать
их по разным файлам. Мы уже вынесли таски
установки MongoDB в отдельный файл роли,
аналогично поступим для тасков управления
конфигурацией. 

Вынесем таски управления конфигом монги в
отдельный файл config_mongo.yml.

В файле main.yml роли будем вызывать таски в
нужном нам порядке:

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
