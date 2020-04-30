# shaadowsky_infra

## hw-09 Ansible-2

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

