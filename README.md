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




!!!!
ОСТАНОВИЛСЯ на 40 листе презы
