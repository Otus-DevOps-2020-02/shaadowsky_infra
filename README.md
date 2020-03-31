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

Создаем сервисный аккаунт для терраформа [инструкция](https://cloud.google.com/iam/docs/creating-managing-service-accounts)

Загрузим провайдер:

```
$ terraform init

Initializing the backend...

Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "google" (hashicorp/google) 2.15.0...

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Полный список предоставляемых terraform'ом ресурсов для работы с GCP можно [посмотреть слева](https://www.terraform.io/docs/providers/google/index.html)

Чтобы запустить VM при помощи terraform, нужно воспользоваться ресурсом [google compute instance](https://www.terraform.io/docs/providers/google/r/compute_instance.html), который позволяет управлять инстансами VM.

Для проверки конфигурационного файла используется

```
$ terraform plan
```

знак _+_ перед наименованием ресурса означает, что ресурс будет добавлен. Далее приведены атрибуты этого ресурса. “<computed>” означает, что данные атрибуты еще не известны terraform'у и их значения будут получены во время создания ресурса.

Внизу приводятся итоги планируемых изменений: количество ресурсов, которые будут добавлены, изменены и удалены.

```
Plan: 1 to add, 0 to change, 0 to destroy.
```

Для запуска инстанса, писанного в конфигурационном файле main.tf, используется команда:

```
$ terraform apply
```

Начиная с версии 0.11 _terraform apply_ запрашивает дополнительное подтверждение при выполнении. Необходимо добавить _-auto-approve_ для отключения этого.

Результатом выполнения команды также будет создание файла _terraform.tfstate_, который представляет собой нечто xml-подобное, в директории terraform. Terraform хранит в этом файле состояние управляемых им ресурсов. Загляните в этот файл и найдите внешний IP-адрес созданного инстанса.

Искать нужные атрибуты ресурсов по state файлу не очень
удобно, поэтому terraform предоставляет команду show для чтения
стейт файла.
Найти внешний IP-адрес созданного инстанса:

```
$ terraform show | grep nat_ip
            nat_ip       = "35.228.16.184"
```

Чтобы не грепать, используют output variable в файле _outputs.tf_. Значение выходных переменных можно посмотреть, используя:

```
$ terraform output
app_external_ip = 104.155.68.69
```

Terraform предлагает команду taint, которая позволяет пометить ресурс, который terraform должен пересоздать, при следующем запуске terraform apply.
Говорим terraform'y пересоздать ресурс VM при следующем применении изменений:

```
$ terraform taint google_compute_instance.app
The resource google_compute_instance.app in the module root
has been marked as tainted!
```

Планируем изменения:

```
$ terraform plan
...
-/+ google_compute_instance.app (tainted) (new resource required)
boot_disk.#: "1" => "1"
boot_disk.0.auto_delete: "true" => “true
```

-/+ означает, что ресурс будет удален и создан вновь.

Входные переменные позволяют нам параметризировать конфигурационные файлы.
Для того чтобы использовать входную переменную ее нужно сначала определить в одном из конфигурационных файлов. Создаём для этих целей еще один конфигурационный файл _variables.tf_ в директории terraform.

Теперь можем использовать input переменные в определении других ресурсов. Чтобы получить значение пользовательской переменной внутри ресурса используется синтаксис var.var_name. Определяем соответствующие параметры ресурсов _main.tf_ через переменные:

```
provider "google" {
  version = "2.15.0"
  project = var.project
  region = var.region
}
```



[]
