# Script para forçar comunicação dos clientes do configuration Manager

## Objetivo do Script
Tem a finalidade de forçar a comunicação do cliente para o Site Server. Reiniciar o serviço, forçar o _RESET_ das políticas, limpar fila de BITS e do DTS, forçar a execução do ccmeval (check health).

## Requisitos para funcionar o script:
1. O cliente precisa ser alcançado pelo servidor / estação de gerenciamento.
2. O protocolo ICMP precisa estar habilitado na rede.
3. O protocolo RPC precisa estar habilitado na rede.
