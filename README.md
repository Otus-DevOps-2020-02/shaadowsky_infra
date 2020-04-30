# shaadowsky_infra


## hw-08 Ansible-1


## Деплой и управление конфигурацией с Ansible


### prerequisites

команды даны для локальной убунту 1804лтс и 

```bash
$ ansible --version
ansible 2.9.6
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/home/shaad/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.17 (default, Nov  7 2019, 10:07:09) [GCC 7.4.0]
```

### Создание плейбука

Создадим плейбук для управления конфигурацией и деплоя приложения. Для этого создайте файл reddit_app.yml в директории ./ansible. Плейбук может состоять из одного или нескольких сценариев (plays). Сценарий позволяет группировать набор заданий (tasks), который Ansible должен выполнить на конкретном хосте (или группе). В плейбуке мы будем использовать один сценарий для управления конфигурацией обоих хостов (приложения и БД)/

=======
1. terraform >0.12.0
2. terraform-провайдер google >2.5.0
3. установлено количество инстансов _app_ = 1
4. настройки load-balancing перенесены в [terraform/files/lb.tf](terraform/files/lb.tf)

### выполнение

Перенеся настройки load-balancing в _terraform/files/_, выполнить подъём стенда.

```bash
$ terraform plan
$ terraform apply (-auto-approve)
```


