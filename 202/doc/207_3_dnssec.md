# DNSSEC - Domain Name System Security Extensions

**Autor:** Caio Abreu Ferreira <abreuferr_gmail.com>  
**Descrição:** Guia completo para proteger um servidor DNS com DNSSEC  
**Peso:** 2

## Descrição

Os candidatos devem ser capazes de configurar um servidor DNS para executar como usuário não-root e em um ambiente chroot jail. Este objetivo inclui a troca segura de dados entre servidores DNS, implementando camadas de segurança essenciais para infraestruturas críticas.

## Áreas de Conhecimento Principais

- Arquivos de configuração do BIND 9
- Configuração do BIND para executar em chroot jail
- Configuração dividida do BIND usando declaração de forwarders
- Configuração e uso de assinaturas de transação (TSIG)
- Conhecimento do DNSSEC e ferramentas básicas
- Conhecimento do DANE e registros relacionados

## Termos e Utilitários

- `/etc/named.conf` - Arquivo principal de configuração do BIND
- `/etc/passwd` - Arquivo de usuários do sistema
- **DNSSEC** - Extensões de segurança para DNS
- `dnssec-keygen` - Ferramenta para geração de chaves criptográficas
- `dnssec-signzone` - Ferramenta para assinatura digital de zonas DNS

---

## Teoria Fundamental

### Requisitos de Segurança do DNSSEC

O DNSSEC (Domain Name System Security Extensions) foi desenvolvido para resolver vulnerabilidades críticas do DNS tradicional, atendendo aos seguintes requisitos de segurança:

#### 1. **Autenticação**
- O servidor DNS comprova cryptograficamente que é realmente o servidor autoritativo responsável por aquela zona
- Previne ataques de spoofing e cache poisoning
- Utiliza assinaturas digitais baseadas em criptografia de chave pública

#### 2. **Integridade dos Dados**
- Garante que os dados DNS não foram corrompidos, alterados ou interceptados durante o transporte
- Cada registro DNS é assinado digitalmente, permitindo verificação de integridade
- Protege contra ataques man-in-the-middle

#### 3. **Prova de Não-Existência**
- Quando o DNS retorna que um domínio não existe (NXDOMAIN), é possível provar criptograficamente que a resposta veio do servidor autoritativo
- Previne ataques que exploram respostas negativas falsas
- Implementado através de registros NSEC e NSEC3

### Tipos de Chaves DNSSEC

**Zone Signing Key (ZSK):** Chave privada usada para assinar os registros da zona. Menor e renovada com mais frequência.

**Key Signing Key (KSK):** Chave privada usada para assinar as ZSKs. Maior e mais segura, renovada com menos frequência.

---

## Instalação

### Instalação dos Componentes DNSSEC

Instalação das bibliotecas Perl necessárias para o funcionamento completo do DNSSEC no BIND:

```bash
sudo apt-get install libnet-dns-zonefile-fast-perl libnet-dns-sec-perl libmailtools-perl libcrypt-openssl-random-perl -y -d
```

**Explicação dos pacotes:**
- `libnet-dns-zonefile-fast-perl`: Parser rápido para arquivos de zona DNS
- `libnet-dns-sec-perl`: Extensões de segurança para manipulação de registros DNSSEC
- `libmailtools-perl`: Ferramentas para manipulação de email (dependência)
- `libcrypt-openssl-random-perl`: Gerador de números aleatórios criptograficamente seguros

---

## Configuração - Servidor Master (NS1)

### 1. Habilitando DNSSEC no BIND

```bash
sudo vi /etc/bind/named.conf.options
```

```bind
options {
    // ... outras configurações ...
    
    // Habilita o processamento de registros DNSSEC
    dnssec-enable yes;
    
    // Habilita a validação de assinaturas DNSSEC para consultas recursivas
    dnssec-validation yes;
    
    // Configura busca automática em repositórios de confiança (DLV - DEPRECATED)
    // Nota: dnssec-lookaside foi descontinuado no BIND 9.12+
    dnssec-lookaside auto;
    
    // ... outras configurações ...
};
```

**Observações importantes:**
- `dnssec-enable yes`: Permite ao servidor processar registros DNSSEC
- `dnssec-validation yes`: Ativa validação de assinaturas DNSSEC
- `dnssec-lookaside`: Descontinuado nas versões mais recentes do BIND

### 2. Criação da Zone Signing Key (ZSK)

```bash
sudo dnssec-keygen -a NSEC3RSASHA1 -b 2048 -n ZONE particula.local
```

**Parâmetros explicados:**
- `-a NSEC3RSASHA1`: Algoritmo de assinatura (SHA-1 com RSA para NSEC3)
- `-b 2048`: Tamanho da chave em bits (2048 é o mínimo recomendado)
- `-n ZONE`: Tipo de chave (para assinatura de zona)
- `particula.local`: Nome da zona a ser assinada

### 3. Criação da Key Signing Key (KSK)

```bash
sudo dnssec-keygen -f KSK -a NSEC3RSASHA1 -b 4096 -n ZONE particula.local
```

**Parâmetros específicos da KSK:**
- `-f KSK`: Define a chave como Key Signing Key
- `-b 4096`: Chave maior para maior segurança (KSK é renovada menos frequentemente)

### 4. Configuração de Permissões

```bash
# Alterando as permissões das chaves para o usuário bind
sudo chown bind:bind Kparticula.local*
```

**Por que isso é importante:**
- O processo bind precisa acessar as chaves privadas para assinar registros
- Permissões inadequadas podem causar falhas na assinatura da zona

### 5. Inclusão das Chaves no Arquivo de Zona

```bash
sudo vi /etc/bind/db.particula.local
```

Adicionar no final do arquivo:

```bind
$INCLUDE /etc/bind/Kparticula.local.+007+09260.key
$INCLUDE /etc/bind/Kparticula.local.+007+40014.key
```

**Explicação:**
- `$INCLUDE`: Diretiva do BIND para incluir conteúdo de outros arquivos
- Os números após o '+' são identificadores únicos das chaves (key tag)
- Apenas as chaves públicas (.key) são incluídas no arquivo de zona

### 6. Assinatura Digital da Zona

```bash
sudo dnssec-signzone -A -3 $(head -c 10 /dev/random | sha1sum | cut -b 1-16) -N INCREMENT -o particula.local -t db.particula.local
```

**Parâmetros detalhados:**
- `-A`: Gera automaticamente registros NSEC para prova de não-existência
- `-3`: Usa NSEC3 em vez de NSEC (mais seguro contra zone walking)
- `$(head -c 10 /dev/random | sha1sum | cut -b 1-16)`: Gera salt aleatório para NSEC3
- `-N INCREMENT`: Incrementa automaticamente o número de série da zona
- `-o particula.local`: Especifica o nome da zona
- `-t`: Imprime estatísticas da assinatura

### 7. Configuração da Zona Assinada

```bash
sudo vi /etc/bind/named.conf.local
```

```bind
// Master zones
zone "particula.local" {
    // ... outras configurações ...
    
    // Aponta para o arquivo assinado digitalmente
    file "/etc/bind/db.particula.local.signed";
    
    // ... outras configurações ...
};
```

### 8. Reinicialização do Serviço

```bash
sudo systemctl restart bind9.service
```

---

## Testes e Validação

### Comandos de Teste Essenciais

#### 1. Verificação das Chaves DNSKEY

```bash
dig DNSKEY particula.local. @localhost +multiline
```

**O que verifica:** Exibe as chaves públicas da zona em formato legível

#### 2. Verificação de Registros com DNSSEC

```bash
dig A particula.local. @localhost +noadditional +dnssec +multiline
```

**O que verifica:** Mostra registros A junto com suas assinaturas RRSIG

#### 3. Verificação Geral de DNSSEC

```bash
dig YOUR-DOMAIN-NAME +dnssec +short
```

**Função:** Verificação rápida dos registros DNSSEC

#### 4. Verificação de Chave Pública

```bash
dig DNSKEY YOUR-DOMAIN-NAME +short
```

#### 5. Verificação da Cadeia de Confiança

```bash
dig DS YOUR-DOMAIN-NAME +trace
```

**Importante:** Este comando rastreia a cadeia de confiança DNSSEC desde a raiz

#### 6. Exibição de Assinaturas DNSSEC

```bash
dig DNSKEY {domain-name}
```

#### 7. Verificação Completa do DNSSEC

```bash
dig +dnssec {domain-name}
```

---

## Configuração - Servidor Slave (NS2)

### 1. Habilitação do DNSSEC

```bash
sudo vi /etc/bind/named.conf.options
```

```bind
options {
    // ... outras configurações ...
    dnssec-enable yes;
    dnssec-validation yes;
    dnssec-lookaside auto;
    // ... outras configurações ...
};
```

### 2. Configuração da Zona Slave

```bash
sudo vi /etc/bind/named.conf.local
```

```bind
// Slave zones
zone "particula.local" {
    // ... outras configurações ...
    
    // Aponta para o arquivo assinado (será sincronizado do master)
    file "/etc/bind/db.particula.local.signed";
    
    // ... outras configurações ...
};
```

### 3. Reinicialização do Serviço

```bash
sudo systemctl restart bind9.service
```

---

## Automação da Assinatura de Zona

### Script de Automatização

A cada alteração no arquivo de zona, é necessário re-assinar. O script abaixo automatiza esse processo:

```bash
sudo vi /etc/bind/zonesigner.sh
```

```bash
#!/bin/sh
# Script para automatizar a assinatura de zonas DNSSEC
# Uso: ./zonesigner.sh <nome_da_zona> <arquivo_da_zona>

PDIR=`pwd`
ZONEDIR="/etc/bind"  # Localização dos arquivos de zona
ZONE=$1              # Nome da zona (ex: particula.local)
ZONEFILE=$2          # Arquivo da zona (ex: db.particula.local)
DNSSERVICE="bind9"   # No CentOS/Fedora use "named"

# Mudança para o diretório das zonas
cd $ZONEDIR

# Extração do número de série atual
SERIAL=`/usr/sbin/named-checkzone $ZONE $ZONEFILE | egrep -ho '[0-9]{10}'`

# Incremento automático do número de série
sed -i 's/'$SERIAL'/'$(($SERIAL+1))'/' $ZONEFILE

# Re-assinatura da zona com novo número de série
/usr/sbin/dnssec-signzone -A -3 $(head -c 10 /dev/random | sha1sum | cut -b 1-16) -N increment -o $1 -t $2

# Recarregamento do serviço DNS
service $DNSSERVICE reload

# Retorno ao diretório original
cd $PDIR
```

### Configuração de Execução Automática

```bash
# Tornar o script executável
sudo chmod +x /etc/bind/zonesigner.sh

# Teste manual do script
sudo /etc/bind/zonesigner.sh particula.local db.particula.local

# Agendamento via cron para execução automática a cada 3 dias
crontab -e
```

Adicionar a linha:

```cron
# Executa a cada 3 dias à meia-noite
0       0       */3     *       *       /etc/bind/zonesigner.sh particula.local db.particula.local
```

**Por que a cada 3 dias?**
- Assinaturas DNSSEC têm tempo de validade limitado
- Re-assinatura periódica previne expiração das assinaturas
- Intervalo de 3 dias oferece boa margem de segurança

---

## Considerações de Segurança

### Proteção das Chaves Privadas

- **Armazenamento seguro:** Chaves privadas devem ser protegidas com permissões restritivas
- **Backup seguro:** Fazer backup das chaves em local seguro e criptografado
- **Rotação de chaves:** Implementar política de rotação regular das chaves

### Monitoramento

- **Logs:** Monitorar logs do BIND para erros de DNSSEC
- **Validade das assinaturas:** Verificar regularmente se as assinaturas não estão expirando
- **Cadeia de confiança:** Monitorar a integridade da cadeia de confiança DNS

### Troubleshooting Comum

1. **Erro de validação:** Verificar sincronização de horário entre servidores
2. **Chaves não encontradas:** Verificar permissões e caminhos dos arquivos
3. **Assinaturas expiradas:** Implementar re-assinatura automática

---

## Recursos Adicionais

- **RFC 4033-4035:** Especificações técnicas do DNSSEC
- **BIND ARM:** Manual oficial do BIND com seção dedicada ao DNSSEC
- **DNSSEC-Tools:** Conjunto de ferramentas para gerenciamento de DNSSEC