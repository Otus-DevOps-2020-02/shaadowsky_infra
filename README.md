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

