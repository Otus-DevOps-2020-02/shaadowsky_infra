# shaadowsky_infra
shaadowsky Infra repository, команды даны для выполнения на локальной Ubuntu 18.04

### установка и настройка packer для работы с GCP

Существует в 3 видах: прекомпилованный бинарь, сорцы, установка для вин/мак.
в моем случае: скачать нужную [версию](https://packer.io/downloads.html), распаковать, переместить в _/usr/local/bin_

Проверим версию:

```
packer -v
```

Для управления ресурсами GCP через сторонние приложения (Packer и Terraform) нужно предоставить этим инструментам информацию (credentials) для аутентификации и управлению ресурсами GCP нашего акаунта.

Установка Application Default Credentials (ADC) позволяет приложениям, работающим с GCP ресурсами и использующим Google API библиотеки, управлять ресурсами GCP через авторизованные API вызовы, используя credentials нужного пользователя.

Создаем АDC:

```
$ gcloud auth application-default login
```

### создание packer template

внутри директории _packer_ создаем файл шаблона - _ubuntu16.json_. Далее будет описана сборка baked-образа ВМ с предустановленными ruby и mongoDB.

Секция шаблона _builders_ отвечает за создание ВМ для билда и создание машинного образа в GCP, состоит из:

• type: "googlecompute" - что будет создавать виртуальную
машину для билда образа (в нашем случае Google Compute
Engine)
• project_id: "infra-272603" - id вашего проекта
• image_family: "reddit-base" - семейство образов к которому
будет принадлежать новый образ
• image_name: "reddit-base-{{timestamp}}" - имя создаваемого
образа
source_image_family: "ubuntu-1604-lts" - что взять за базовый
образ для нашего билда
• zone: "europe-north1-c" - зона, в которой запускать VM для
билда образа
• ssh_username: "appuser" - временный пользователь, который
будет создан для подключения к VM во время билда и
выполнения команд провижинера (о нем поговорим ниже)
• machine_type: "f1-micro" - тип инстанса, который запускается
для билда

секция _provisioners_ позволяет устанавливать нужное ПО, производить настройки системы и конфигурацию приложений на созданной VM.  Опция _execute_command_ позволяет указать, каким способом будет запускаться скрипт.

После описания шаблона необходимо проверить шаблон командой

```
packer validate ubuntu.json
```

Если проверка на ошибки прошла успешно, запускаем сборку образа:

```
$ packer build ubuntu16.json
```

В браузерной коносли можно увидеть как packer запустил инстанс ВМ.

Собранный образ появится в браузерной консоли по пути Compute Engine --> Images.


### Travis CI check

testapp_IP = 35.228.88.190

testapp_port = 9292
