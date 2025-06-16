# DNS Chroot - Configuração de Segurança Avançada para Servidores DNS

**Título:** DNS Chroot  
**Autor:** Caio Abreu Ferreira <abreuferr_gmail.com>  
**Descrição:** Protegendo um servidor DNS  
**Peso:** 2

## Descrição

Os candidatos devem ser capazes de configurar um servidor DNS para executar como usuário não-root e executar em um ambiente chroot jail. Este objetivo inclui a troca segura de dados entre servidores DNS.

## Áreas de Conhecimento Chave

- Arquivos de configuração do BIND 9
- Configuração do BIND para executar em chroot jail
- Configuração dividida do BIND usando a declaração forwarders
- Configuração e uso de assinaturas de transação (TSIG)
- Conhecimento sobre DNSSEC e ferramentas básicas
- Conhecimento sobre DANE e registros relacionados

## Termos e Utilitários

- `/etc/named.conf`
- `/etc/passwd`
- DNSSEC
- `dnssec-keygen`
- `dnssec-signzone`

## O que é Chroot Jail?

**Chroot** (Change Root) é uma técnica de segurança que isola um processo em um diretório específico, fazendo com que ele "veja" esse diretório como se fosse o diretório raiz (/) do sistema. Isso cria uma "prisão" (jail) que:

### Benefícios de Segurança

- **Isolamento do Sistema:** O processo não pode acessar arquivos fora do ambiente chroot
- **Contenção de Ataques:** Limita o dano em caso de comprometimento do serviço
- **Redução da Superfície de Ataque:** Minimiza recursos disponíveis para um atacante
- **Princípio do Menor Privilégio:** O serviço opera apenas com os recursos necessários

### Limitações do Chroot

- **Não é virtualização completa:** Processos ainda compartilham kernel e recursos do sistema
- **Configuração complexa:** Requer replicação de dependências no ambiente isolado
- **Manutenção adicional:** Updates e patches precisam ser aplicados no ambiente chroot

## Configuração Chroot para DNS Cache/Master/Slave

### Passo 1: Preparação do Sistema

```bash
# Pare o serviço BIND antes de fazer as modificações
# Isso evita conflitos durante a reconfiguração
sudo systemctl stop bind9.service

# Verifique se o serviço foi parado completamente
sudo systemctl status bind9.service
```

> **Importante:** Sempre pare o serviço antes de fazer alterações estruturais para evitar corrupção de dados ou conflitos de configuração.

### Passo 2: Configuração do Systemd

Crie um novo arquivo de configuração do systemd para que o processo BIND seja executado com um usuário sem privilégios de root e em ambiente chroot.

```bash
sudo vi /etc/systemd/system/bind9.service
```

**Conteúdo do arquivo:**

```ini
[Unit]
Description=BIND Domain Name Server
Documentation=man:named(8)
# Garante que o serviço inicie após a rede estar disponível
After=network.target
# Opcional: adicionar dependência de sistema de arquivos
After=local-fs.target

[Service]
# Executa o BIND em modo foreground (-f), como usuário bind (-u), 
# em chroot jail (-t)
ExecStart=/usr/sbin/named -f -u bind -t /var/lib/named
# Comando para recarregar configurações sem parar o serviço
ExecReload=/usr/sbin/rndc reload
# Comando para parar o serviço de forma controlada
ExecStop=/usr/sbin/rndc stop
# Reinicia automaticamente o serviço se ele falhar
Restart=on-failure
# Aguarda 5 segundos antes de reiniciar
RestartSec=5
# Define o tipo de serviço (simple = processo principal)
Type=simple
# Usuário e grupo para execução do serviço
User=bind
Group=bind

[Install]
# Define que o serviço deve iniciar no modo multi-usuário
WantedBy=multi-user.target
```

### Parâmetros Explicados

- **`-f`**: Executa em foreground (necessário para systemd)
- **`-u bind`**: Define o usuário para execução (segurança)
- **`-t /var/lib/named`**: Define o diretório chroot

### Passo 3: Habilitação do Novo Serviço

```bash
# Recarregue as configurações do systemd para reconhecer o novo arquivo
sudo systemctl daemon-reload

# Habilite o serviço para iniciar automaticamente na inicialização
sudo systemctl enable bind9

# Verifique se a habilitação foi bem-sucedida
sudo systemctl is-enabled bind9
```

### Passo 4: Criação da Estrutura de Diretórios Chroot

```bash
# Crie a estrutura completa de diretórios necessária para o chroot
# -p cria diretórios pais se não existirem
sudo mkdir -p /chroot/{etc,dev,var/cache/bind,var/run/named,var/log}

# Adicione diretório para bibliotecas se necessário
sudo mkdir -p /chroot/{lib,lib64,usr/lib}

# Crie diretório para arquivos temporários
sudo mkdir -p /chroot/tmp
```

### Passo 5: Criação de Dispositivos Especiais

Os dispositivos especiais são necessários para o funcionamento correto do BIND:

```bash
# /dev/null - dispositivo que descarta todos os dados escritos
sudo mknod /chroot/dev/null c 1 3

# /dev/random - gerador de números aleatórios (criptografia forte)
sudo mknod /chroot/dev/random c 1 8

# /dev/urandom - gerador de números pseudo-aleatórios (mais rápido)
sudo mknod /chroot/dev/urandom c 1 9

# /dev/zero - gera uma sequência infinita de bytes zero
sudo mknod /chroot/dev/zero c 1 5
```

> **Explicação dos Dispositivos:**
> - `c`: indica dispositivo de caractere
> - `1`: major number (identifica o driver)
> - `3,8,9,5`: minor numbers (identificam dispositivos específicos)

### Passo 6: Migração dos Arquivos de Configuração

```bash
# Mova os arquivos de configuração existentes para o chroot
sudo mv /etc/bind /chroot/etc/

# Crie um link simbólico para manter compatibilidade
sudo ln -s /chroot/etc/bind /etc/bind

# Verifique se o link foi criado corretamente
ls -la /etc/bind
```

### Passo 7: Configuração de Permissões

```bash
# Defina o proprietário recursivamente para o usuário bind
sudo chown bind:bind -R /chroot/

# Configure permissões apropriadas
sudo chmod 755 -R /chroot/

# Permissões específicas para diretórios sensíveis
sudo chmod 750 /chroot/etc/bind
sudo chmod 755 /chroot/var/cache/bind
sudo chmod 755 /chroot/var/run/named

# Torne o grupo bind proprietário recursivamente
sudo chgrp bind -R /chroot/
```

### Passo 8: Configuração do Script de Inicialização (Sistemas Legados)

Para sistemas que ainda usam init.d (opcional, principalmente para compatibilidade):

```bash
sudo vi /etc/init.d/bind9
```

Localize e modifique a linha do PIDFILE:
```bash
# Alterar de:
# PIDFILE=/var/run/named/named.pid
# Para:
PIDFILE=/chroot/var/run/named/named.pid
```

### Passo 9: Configuração de Logs no Chroot

A configuração de logs no BIND utiliza o conceito de `include` para segmentar a configuração em múltiplos arquivos, facilitando a manutenção:

```bash
# Faça backup da configuração original
sudo cp /etc/bind/named.conf{,.origin}

# Edite a configuração principal
sudo vi /etc/bind/named.conf
```

Adicione ao final do arquivo `/etc/bind/named.conf`:

```bind
include "/etc/bind/named.conf.log";
```

**Criação do arquivo de configuração de log:**

```bash
sudo vi /etc/bind/named.conf.log
```

**Conteúdo do arquivo de log:**

```bind
logging {
    channel bind_log {
        # Utiliza syslog com facility daemon
        syslog daemon;
        severity info;
        print-category yes;
        print-severity yes;
        print-time yes;
    };
    # Configurações de categorias de log
    category default { bind_log; };
    category update { bind_log; };
    category update-security { bind_log; };
    category security { bind_log; };
    category queries { bind_log; };
    # Suprime logs de servidores com configuração incorreta
    category lame-servers { null; };
};
```

### Explicação das Categorias de Log

- **`default`**: Logs gerais do servidor DNS
- **`update`**: Atualizações dinâmicas de registros DNS
- **`update-security`**: Tentativas de atualização não autorizadas
- **`security`**: Eventos relacionados à segurança (TSIG, ACLs)
- **`queries`**: Consultas DNS recebidas pelo servidor
- **`lame-servers`**: Servidores DNS mal configurados (definido como null para reduzir ruído)

**Aplicação das configurações:**

```bash
# Reinicie o serviço para aplicar as configurações
sudo systemctl restart bind9

# Verifique se o serviço iniciou corretamente
sudo systemctl status bind9
```

### Passo 10: Inicialização dos Serviços

```bash
# Inicie o serviço BIND em ambiente chroot
sudo systemctl start bind9.service

# Verifique o status do serviço
sudo systemctl status bind9.service
```

## Visualização e Monitoramento de Logs

### Opções para Visualizar Logs do BIND

O BIND configurado com syslog utiliza o journald do systemd, proporcionando várias opções de visualização:

```bash
# Logs do BIND em tempo real
sudo journalctl -u bind9 -f

# Últimas 20 linhas dos logs
sudo journalctl -u bind9 -n 20

# Logs do BIND de hoje
sudo journalctl -u bind9 --since today

# Logs com filtro por categoria específica
sudo journalctl -u bind9 | grep -E "(queries|security|update)"

# Todos os logs do sistema em tempo real
sudo journalctl -f

# Logs do BIND das últimas 2 horas
sudo journalctl -u bind9 --since "2 hours ago"

# Logs do BIND com formato JSON para análise automatizada
sudo journalctl -u bind9 -o json

# Logs do BIND entre datas específicas
sudo journalctl -u bind9 --since "2024-01-01" --until "2024-01-31"
```

### Análise de Logs Comuns

**Exemplos de logs importantes a observar:**

```bash
# Verificar inicialização do serviço
sudo journalctl -u bind9 | grep "starting BIND"

# Verificar carregamento de zonas
sudo journalctl -u bind9 | grep "zone.*loaded"

# Verificar transferências de zona (se configurado como slave)
sudo journalctl -u bind9 | grep "transfer"

# Verificar tentativas de ataque ou consultas suspeitas
sudo journalctl -u bind9 | grep -i "denied\|refused\|security"
```

## Verificação e Diagnóstico

### Comandos de Verificação

```bash
# Verifique se o processo está executando em chroot
ps aux | grep named

# Verifique se o BIND está escutando nas portas corretas
sudo netstat -tulnp | grep :53

# Teste a funcionalidade do DNS
nslookup google.com localhost

# Verifique os logs usando journalctl
sudo journalctl -u bind9 -f
```

### Estrutura Final do Chroot

Após a configuração, a estrutura deve ficar assim:
```
/chroot/
├── dev/
│   ├── null
│   ├── random
│   ├── urandom
│   └── zero
├── etc/
│   └── bind/
│       ├── named.conf
│       ├── named.conf.local
│       └── db.*
├── var/
│   ├── cache/bind/
│   ├── run/named/
│   └── log/
└── tmp/
```

## Solução de Problemas Comuns

### Problema: Falha ao Iniciar o Serviço

**Sintomas:** `systemctl start bind9` falha

**Soluções:**
```bash
# Verifique se todos os diretórios existem
ls -la /chroot/

# Verifique permissões
ls -la /chroot/ -R | grep bind

# Teste a configuração
sudo named-checkconf /chroot/etc/bind/named.conf
```

### Problema: Logs Não Aparecem

**Sintomas:** Ausência de logs em `/var/log/bind/`

**Soluções:**
```bash
# Verifique se o socket de log existe
ls -la /chroot/dev/log

# Crie o socket se necessário
sudo mknod /chroot/dev/log s

# Reinicie os serviços
sudo systemctl restart rsyslog bind9
```

### Problema: Resolução DNS Falha

**Sintomas:** `nslookup` retorna erro

**Soluções:**
```bash
# Verifique se o processo está executando
sudo systemctl status bind9

# Teste conectividade local
telnet localhost 53

# Verifique configuração de firewall
sudo ufw status
```

## Considerações de Segurança Avançadas

### Hardening Adicional

1. **SELinux/AppArmor:** Configure políticas específicas para o BIND
   ```bash
   # Para sistemas com SELinux
   sudo setsebool -P named_write_master_zones on
   ```

2. **Limitação de Recursos:** Configure limites no systemd
   ```ini
   [Service]
   MemoryMax=512M
   CPUQuota=50%
   ```

3. **Monitoramento:** Implemente alertas para falhas
   ```bash
   # Adicione ao crontab
   */5 * * * * systemctl is-active bind9 || echo "BIND down" | mail admin@domain.com
   ```

### Manutenção do Ambiente Chroot

1. **Atualizações:** Mantenha binários e bibliotecas atualizados
2. **Backup:** Faça backup regular do diretório `/chroot/`
3. **Monitoramento:** Implemente alertas para uso de espaço em disco
4. **Auditoria:** Revise logs regularmente para detectar anomalias

## Próximos Passos

Após implementar o chroot:

1. **Implementar TSIG** para comunicação segura entre servidores
2. **Configurar DNSSEC** para assinatura digital das zonas
3. **Implementar rate limiting** para prevenir ataques DDoS
4. **Configurar monitoring** com Nagios, Zabbix ou similar
5. **Automatizar backups** das configurações e zonas

Este guia fornece uma implementação robusta de chroot para servidores DNS, significativamente melhorando a postura de segurança da infraestrutura DNS.