# shaadowsky_infra

## hw-07 Terraform-2

## Принципы организации инфраструктурного кода и работа над инфраструктурой в команде на примере Terraform

### prerequisites

команды даны для выполнения на локальной Ubuntu 18.04

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

#### добавление правил брендмауэра

проверим правило разрешения ssh-доступа:

```bash
$ gcloud compute firewall-rules list
NAME                    NETWORK  DIRECTION  PRIORITY
...
default-allow-ssh       default  INGRESS    65534     tcp:22                              False
...
```

На данный момент этого правила нет в конфигурационных файлах терраформа. Врезультате чего нет контроля над управлением нужными нам правилами файервола.

После правила файервола для puma cоздаем ресурс в _main.tf_  с такой же конфигурацией, что и у выведенного выше правила.

```code
resource "google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```

ВНИМАНИЕ, при попытке выполнения _terraform apply_ появится ошибка (см. ниже), вызванная наличием вручную добавленного правила.

```bash
Error: Error creating Firewall: googleapi: Error 409: The resource 'projects/infra-272603/global/firewalls/default-allow-ssh' already exists, alreadyExists
```

Т.к terraform ничего не знает о существующем правиле файервола (а всю информацию, об известных ему ресурсах, он хранит в state файле), то при выполнении команды apply terraform пытается создать новое правило файервола. Для того чтобы сказать terraform-у не создавать новое правило, а управлять уже имеющимся, в его "записную книжку" (state файл) о всех ресурсах, которыми он управляет, нужно занести информацию о существующем правиле.

Команда _terraform import_ позволяет добавить информацию о созданном без помощи Terraform ресурсе в state файл. В директории terraform выполните команду:

```bash
$ terraform import google_compute_firewall.firewall_ssh default-allow-ssh
google_compute_firewall.firewall_ssh: Importing from ID "default-allow-ssh"...
google_compute_firewall.firewall_ssh: Import prepared!
  Prepared google_compute_firewall for import
google_compute_firewall.firewall_ssh: Refreshing state... [id=default-allow-ssh]

Import successful!
```

Из планируемых изменений видно, что description(описание) существующего правила будет удалено. Добавим описание в конфигурацию ресурса firewall_ssh.resource:

```code
"google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"
  description = "Allow SSH from anywhere"
```

Выполняем _apply_:

```bash
$ terraform apply
```

#### ресурс IP-адреса

Зададим IP для инстанса с приложением в виде внешнего ресурса. Для этого определим ресурс _google_compute_address_ в конфигурационном файле _main.tf_.

```code
resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}
```

Если после добавления этого ресурса на следующем шаге падает терраформ с ошибкой Quota 'STATIC_ADDRESSES' exceeded, зайте в VPC Network -> external ip addresses и удалитm static ip, который был зарезервирован под инстанс бастиона.

Пересоздаём инфраструктуру:

```bash
$ terraform destroy
$ teraaform apply
```

Терраформ параллельно создает определйнные выше ресурсы.

Для того чтобы использовать созданный IP адрес в нашем ресурсе VM нам необходимо сослаться на атрибуты ресурса, который этот IP создает, внутри конфигурации ресурса VM. В конфигурации ресурса VM определите, IP адрес для создаваемого инстанса.

```code
network_interface {
 network = "default"
 access_config {
   nat_ip = google_compute_address.app_ip.address
 }
}
```

Ссылку в одном ресурсе на атрибуты другого тераформ понимает как зависимость одного ресурса от другого. Это влияет на очередность создания и удаления ресурсов при применении изменений.

Пересоздаём все ресурсы и смотрим на очередность создания ресурсов сейчас

```bash
$ terraform destroy
$ terraform plan
$ terraform apply
google_compute_address.app_ip: Creating...
google_compute_firewall.firewall_puma: Creating...
google_compute_firewall.firewall_ssh: Creating...
...
google_compute_address.app_ip: Creation complete after 12s (ID: reddit-app-ip)
google_compute_instance.app: Creating...
```

Ресурс VM начал создаваться только после завершения создания IP адреса в результате неявной зависимости этих ресурсов.

Terraform поддерживает также явную зависимость, используя параметр _[depends_on](https://www.terraform.io/docs/configuration/resources.html)_.

#### структуризация (выделение) ресурсов

Вынесем БД на отдельный инстанс VM.

Для этого необходимо в директории _packer_, где содержатся шаблоны для билда VM, создать два новых шаблона _db.json_ и _app.json_.

При помощи шаблона _
[db.json](packer/db.json)_ собирается образ VM, содержащий установленную MongoDB.

Шаблон _[app.json](packer/app.json)_ собирается образа VM, с установленными Ruby.

В качестве базового образа для создания образа использован уже имеющийся шаблон  _[ubuntu16.json](packer/ubuntu16.json)_.

Разбиваем конфиг из _main.tf_ на несколько конфигов.

Вынесем конфигурацию для VM с приложением в файл _app.tf_. Провижионерами пока пренебрегаем.

Внести новую переменную для образов приложения и БД в _variables.tf_

```code
variable app_disk_image {
  description = "Disk image for reddit app"
  default = "reddit-app-base"
}
variable db_disk_image {
  description = "Disk image for reddit db"
  default = "reddit-db-base"
}```

Вынесем правило файервола для ssh-доступа в файл _vpc.tf_. Правило будет применимо для всех инстансов нашей сети.

В итоге, в файле _main.tf_ должно остаться только определение провайдера:

```code
provider "google" {
  version = "~> 2.15"
  project = var.project
  region = var.region
}
```

СЮРПРИЗ, надо создать образа пакером. Перейте в диру packer и создать образа, определив файл с переменными:

```bash
$ cd <project_dir>/packer
$ packer validate -var-file=variables.json app.json
$ packer validate -var-file=variables.json db.json
$ packer build -var-file=variables.json app.json
$ packer build -var-file=variables.json db.json
```

Перейти в диру с терраформом, отформатировать файлы и проверить корректность создания проекта:

```bash
$ cd <project_dir>/terraform
$ terraform fmt
$ terraform plan
$ terraform apply
```

(note) в процессе пришлось пересоздать образы с предыдущих шагов

Проверил, что всё ОК и удалил созданные ресурсы

```bash
$ terrafrom destroy
```


#### создание модулей

Теперь кофнигурация инфраструктуры готова к работе с модулями. Создаем внутри директории _terraform_ директорию _modules_, в которой будут определятся, внезапно, модули.

Внутри _modules/_ создаем директории _db/_ и _app/_. Внутри каждой из созданных директорий создаем файлы _main.tf_, _variables.tf_, _outputs.tf_.

```
$ mkdir modules/{db,app}
$ touch modules/{db,app}/{main,variables,outputs}.tf
```

Скопировать содержимое _db.tf_ и _app.tf_ в соответствующие им _main.tf_ модулей.

Определяем переменные  _modules/db/variables.tf_:

```code
variable public_key_path {
  description = "Path to the public key used to connect to instance"
}

variable zone {
  description = "Zone"
}

variable db_disk_image {
  description = "Disk image for reddit db"
  default     = "reddit-db-base"
}
```

Определяем переменные  _modules/app/variables.tf_:

```code
variable public_key_path {
  description = "Path to the public key used to connect to instance"
}

variable zone {
  description = "Zone"
}

variable app_disk_image {
  description = "Disk image for reddit app"
  default     = "reddit-app-base"
}
```

Определяем выходные переменные для приложения - _modules/app/outputs.tf_

```code
output "app_external_ip" {
  value = google_compute_instance.app.network_interface.0.access_config.0.assigned_nat_ip
}
```

Прежде чем вызывать и проверять модули, для начала удалим _db.tf_ и _app.tf_ в нашей директории, чтобы terraform перестал их использовать.

В файл main.tf, где определен провайдер, вставим секции вызова созданных модулей.

```code
module "app" {
  source          = "./modules/app"
  public_key_path = var.public_key_path
  zone            = var.zone
  app_disk_image  = var.app_disk_image
}

module "db" {
  source          = "./modules/db"
  public_key_path = var.public_key_path
  zone            = var.zone
  db_disk_image   = var.db_disk_image
}
```

Чтобы начать использовать модули, нужно их загрузить из указанного источника. В нашем случае источником модулей будет локальная папка на диске. Используем команду для загрузки модулей. В директории terraform выполнить:

```bash
$ terraform get
- app in modules/app
- db in modules/db

$ tree .terraform
.terraform
├── modules
│   └── modules.json
└── plugins
    └── linux_amd64
        ├── lock.json
        └── terraform-provider-google_v2.15.0_x4

3 directories, 3 files

```

Модули будут загружены в директорию _.terraform_, в которой уже содержится провайдер.

Применяем _terraform plan_:

```bash
$ terraform plan

Error: Reference to undeclared resource

  on outputs.tf line 2, in output "app_external_ip":
   2:   value = google_compute_instance.app.network_interface[0].access_config[0].nat_ip

A managed resource "google_compute_instance" "app" has not been declared in
the root module.
```

Оп, ошибка. Надо переопределить переменную для внешнего IP инстанса:

```code
output "app_external_ip" {
  value = module.app.app_external_ip
}
```

Все ОК:

```bash
$ terraform plan
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.
...
Plan: 6 to add, 0 to change, 0 to destroy.
```

Теперь выполняем то же самое для _vpc.tf_ из директории _terraform/_.

```bash
$ mkdir modules/vpc/
$ touch modules/vpc/{outputs,variables}.tf
$ mv vpc.tf modules/vpc/main.tf
```

Объявляем модуль vpc в основном _main.tf_:

```code
module "vpc" {
  source          = "./modules/vpc"
}
```

подгружаем модуль и проверяем:

```bash
$ terraform get
- vpc in modules/vpc
$ terraform plan
...
Plan: 6 to add, 0 to change, 0 to destroy.
$ terraform apply
...
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

#### параметризация модулей

Приведем пример параметризации модулей за счет использования input переменных. В созданном модуле vpc используем переменную для конфигурации допустимых адресов.

_terraform/vpc/main.tf_:

```code
resource "google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"
  allow {
   protocol = "tcp"
    ports = ["22"]
  }
  source_ranges = var.source_ranges
}
```

_terraform/vpc/variables.tf_:

```code
variable source_ranges {
  description = "Allowed IP addresses"
  default = ["0.0.0.0/0"]
}
```

В результате этих изменений можно будет задавать диапазоны IP-адресов, с которых доступен проект, для правила файервола при вызове модуля.

#### переиспользование модулей

Основная задача, решаемая модулями - увеличение переиспользования кода, что помогает следовать принципу DRY (Do not Repeat Yourself). Описанная в модулях инфраструктура может быть использована на разных стадиях непрерывной поставки с необходимыми условиями. Далее создаем инфру для stage и production с использованием аозданных модулей.

В директории _terraform_ создаем директории _stage_ и _prod_. Затем скопируем файлы _main.tf_, _variables.tf_, _outputs.tf_, _terraform.tfvars_ из директории _terraform_ в каждую из созданных директорий. Поменяем пути в _terraform/main.tf_ на ../modules/xxx. Инфраструктура в обоих окружениях будет идентична, со следующими отличиями: в stage будет открыт ssh-доступ для всех ip-адресов, а в окружении prod откроем доступ только для своего IP. Выполняется изменением параметра source_ranges в модуле vpc.

```bash
$ mkdir prod stage
$ cp terraform.tfvars stage/
$ cp {main,variables,outputs}.tf stage/
$ cp terraform.tfvars prod/
$ cp {main,variables,outputs}.tf prod/

```

_terraform/stage/main.tf_:

```code
...
module "vpc" {
  source        = "../modules/vpc"
  source_ranges = ["0.0.0.0/0"]
}
```

_terraform/prod/main.tf_:

```code
...
module "vpc" {
  source = "../modules/vpc"
  source_ranges = ["local_ip/32"]
}
```

#### работа с реестром модулей

В сентябре 2017 компания HashiCorp запустила публичный реестр модулей для terraform. До этого модули можно было либо хранить либо локально, либо забирать из Git, Mercurial или HTTP. На главной странице можно искать необходимые модули по названию и фильтровать по провайдеру. Например, [ссылка](https://registry.terraform.io/browse?provider=google) модулей для провайдера google. Модули бывают Verified и обычные. Verified это модули от HashiCorp и ее партнеров.

попробуем воспользоваться модулем [storage-bucket](https://registry.terraform.io/modules/SweetOps/storage-bucket/google) для создания бакета в сервисе Storage.

Создаем в папке _terraform_ файл _storage-bucket.tf_ со следующим содержанием:

```code
provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

module "storage-bucket" {
  source  = "SweetOps/storage-bucket/google"
  version = "0.3.0"

  # Имя поменяйте на другое
  name = "storage-bucket-shaad"
}

output storage-bucket_url {
  value = module.storage-bucket.url
}
```

Создайть или скопировать готовые _variables.tf_ и _terraform.tfvars_ для проекта и региона и применить конфигурацию тераформа. Проверить с помощью gcloud или веб-консоли, что бакеты создались и доступны.

#### (starred task) хранение стейт файла в удаленном бэкенде

чтобы не привязываться к аппаратной составляющей, файл _terraform.tfstate_ можно положить в бакет (storage bucket) в Google Cloud Storage (GCS).

в файле _terraform/storage-backet.tf_ вносим описание бакета и ссылку доступа к нему:

```code
module "tf-backend-bucket-prod" {
  source  = "git::https://github.com/SweetOps/terraform-google-storage-bucket.git?ref=master"
  name = "tf-back-prod"
  stage = "prod"
  location = "europe-north1"
}
output tf-backend-bucket-prod-url {
  value = module.tf-backend-bucket-prod.url
}
```

**ВНИМАНИЕ** использовать сразу master в ссылках на какие-либо проекты в значении source опасно!! Использовано в учебных целях, в продакшн кейсах найти способ указания конкретной версии

**memo** можно из _terraform/storage-backet.tf_ впинать в _terraform/modules/_, вроде логичнее получится, все модули в одном месте.

После описания бакетов в файлы _main.tf_ каждого окружения (в моём случае prod и stage) вносим в начало файла в секцию terraform  указание на бакет.

```code
terraform {
  backend "gcs" {
    bucket = "<окружение>-<name_of_bucket>"
  }
}
```

Значение bucket выставляется так: НазваниеОкружения-NameБакета, например, для бакета окружения stage в мом случае будет так:

```code
    bucket = "stage-<name_of_bucket>"
```
