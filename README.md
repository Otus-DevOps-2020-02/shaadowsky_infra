# shaadowsky_infra
shaadowsky Infra repository

_ssh-bastion 35.217.43.15_

_someinternalhost 10.166.0.8_

_создан ключ appuser на локальной машине, в metadata ssh public keys проекта добавлена публичный ключ appuser_

### подключение к хосту, находящемуся за ssh-bastion

реализуется через ssh версии =>7.3

    ssh -i ~/.ssh/appuser -J appuser@35.217.43.15 appuser@10.166.0.8

в общем случае выглядит так (подразумеваем, что ключ один и пользователь на всех машинах совпадает):

    ssh -J <bastion-host> <remote-host>

где bastion-host - машина, на которой настроен ssh-bastion, через которую мы подключаемся

Можно подключаться на разные порты:

    ssh -J <user>@<bastion>:<port> <user>@<remote>:<port>

### подключение к хосту, находящемуся за ssh-bastion, одной командой типа ssh someinternalhost

для подключения используется та же опция ssh proxyjump, что и в примере выше.

для упрощения жизни необходимо откорректировать файл _~/.ssh/config_ на локальной машине следующим образом:

    # OTUS ssh-bastion
    Host bastion
      User appuser
      PreferredAuthentications publickey
      IdentityFile ~/.ssh/appuser
     HostName 35.217.43.15

    # Otus remote host
    Host someinternalhost
      User appuser
      HostName 10.166.0.8
      ProxyJump bastion

после этого remote host доступен по команде _ssh someinsternalhost
