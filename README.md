# shaadowsky_infra

## hw-08 Ansible-1

## Знакомство с Ansible

### prerequisites

команды даны для выполнения на локальной Ubuntu 18.04

1. Python 2.7.17
2. pip 20.0.2 from /home/shaad/.local/lib/python2.7/site-packages/pip (python 2.7)
3. ansible 2.9.6

### выполнение

создаем в директории _ansible/_ файл _requirements.txt_

```bash
mkdir ansible
echo "ansible>=2.4" > ansible/requirements.txt
```

установить ansible любым способом:

```
pip install -r requirements.txt
pip install ansible>=2.4
easy_install `cat requirements.txt`
yum install ansible
apt install ansible
```
