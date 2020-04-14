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

```
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

```
Error: Error creating Firewall: googleapi: Error 409: The resource 'projects/infra-272603/global/firewalls/default-allow-ssh' already exists, alreadyExists
```

Т.к terraform ничего не знает о существующем правиле файервола (а всю информацию, об известных ему ресурсах, он хранит в state файле), то при выполнении команды apply terraform пытается создать новое правило файервола. Для того чтобы сказать terraform-у не создавать новое правило, а управлять уже имеющимся, в его "записную книжку" (state файл) о всех ресурсах, которыми он управляет, нужно занести информацию о существующем правиле.

Команда _terraform import_ позволяет добавить информацию о созданном без помощи Terraform ресурсе в state файл. В директории terraform выполните команду:

```
$ terraform import google_compute_firewall.firewall_ssh default-allow-ssh
google_compute_firewall.firewall_ssh: Importing from ID "default-allow-ssh"...
google_compute_firewall.firewall_ssh: Import prepared!
  Prepared google_compute_firewall for import
google_compute_firewall.firewall_ssh: Refreshing state... [id=default-allow-ssh]

Import successful!
```

Из планируемых изменений видно, что description(описание) существующего правила будет удалено. Добавим описание в конфигурацию ресурса firewall_ssh.resource:

```
"google_compute_firewall" "firewall_ssh" {
  name = "default-allow-ssh"
  network = "default"
  description = "Allow SSH from anywhere"
```

Выполняем _apply_:

```
$ terraform apply
```

#### ресурс IP-адреса

Зададим IP для инстанса с приложением в виде внешнего ресурса. Для этого определим ресурс _google_compute_address_ в конфигурационном файле _main.tf_.

```
resource "google_compute_address" "app_ip" {
  name = "reddit-app-ip"
}
```

Если после добавления этого ресурса на следующем шаге падает терраформ с ошибкой Quota 'STATIC_ADDRESSES' exceeded, зайте в VPC Network -> external ip addresses и удалитm static ip, который был зарезервирован под инстанс бастиона.

Пересоздаём инфраструктуру:

```
$ terraform destroy
$ teraaform apply
```

Терраформ параллельно создает определйнные выше ресурсы.

Для того чтобы использовать созданный IP адрес в нашем ресурсе VM нам необходимо сослаться на атрибуты ресурса, который этот IP создает, внутри конфигурации ресурса VM. В конфигурации ресурса VM определите, IP адрес для создаваемого инстанса.

```
network_interface {
 network = "default"
 access_config {
   nat_ip = google_compute_address.app_ip.address
 }
}
```

Ссылку в одном ресурсе на атрибуты другого тераформ понимает как зависимость одного ресурса от другого. Это влияет на очередность создания и удаления ресурсов при применении изменений.

Пересоздаём все ресурсы и смотрим на очередность создания ресурсов сейчас

```
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

Вынесем конфигурацию для VM с приложением в файл _[app.tf](terraform/app.tf)_. Провижионерами пока пренебрегаем.
