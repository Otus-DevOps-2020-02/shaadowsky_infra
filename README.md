# shaadowsky_infra

## shaadowsky Infra repository

### prerequisites

команды даны для выполнения на локальной Ubuntu 18.04

1. terraform >0.12.0
2. terraform-провайдер google >2.5.0
3. удалены ключи пользователя appuser из метаданных проекта
4. нужен собранный образ reddit-full из предыдущего задания по [packer](packer/)

### установка terraform

Необходимо [скачать](https://www.terraform.io/downloads.html) необходимую версию terraform и распаковать в _/usr/local/bin_.

Проверим версию

```
$ terraform -v
Terraform v0.12.24
```

### выполнение работы

_main.tf_ - главный конфигурационный файл с декларативным описанием
