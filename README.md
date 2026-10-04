# DevOps проект MTS ENGINEER HACK

## Содержание

- [О проекте](#1-о-проекте)
- [Архитектура](#2-архитектура)
- [Используемые технологии](#3-используемые-технологии)
- [Требования к среде](#4-требования-к-среде)
- [Подготовка пользователей](#5-подготовка-пользователей)
- [Настройка SSH](#6-настройка-ssh)
- [Настройка IP-адресов](#7-настройка-ip-адресов)
- [Проверка Ansible](#8-проверка-ansible)
- [Развёртывание](#9-развёртывание)
- [Kubernetes](#10-kubernetes)
- [Тестовое приложение](#11-тестовое-приложение)
- [Gateway API](#12-gateway-api)
- [Проверка Gateway API](#13-проверка-gateway-api)
- [Мониторинг](#14-мониторинг)
- [Проверка мониторинга](#15-проверка-мониторинга)
- [Grafana](#16-grafana)
- [Логирование](#17-логирование)
- [Loki и проверка логов](#18-loki-и-проверка-логов)
- [HTTP-коды и дополнительные метрики](#19-http-коды-и-дополнительные-метрики)
- [Повторный запуск](#20-повторный-запуск)
- [Структура проекта](#21-структура-проекта)
- [Дополнительные возможности](#22-дополнительные-возможности)
- [Известные ограничения](#23-известные-ограничения)
- [Безопасность](#24-безопасность)
- [Быстрый запуск](#25-быстрый-запуск)

---

## 1. О проекте

Проект представляет собой автоматизированное развёртывание Kubernetes-кластера, простого веб-приложения, мониторинга и сбора логов.

В качестве приложения используется Nginx. Доступ к нему организован через Kubernetes Gateway API.

**Основные компоненты:**

- Kubernetes
- Nginx
- Gateway API + NGINX Gateway Fabric
- Prometheus
- Grafana
- Fluentd
- Loki
- Ansible

Развёртывание выполняется одной командой:

```bash
./deploy.sh
```

Проверка:

```bash
./verify.sh
```

---

## 2. Архитектура

```
                       Пользователь
                            |
                            v
                   NodePort :32630
                            |
                            v
                NGINX Gateway Fabric
                            |
                            v
                       Gateway API
                            |
                            v
                       HTTPRoute
                            |
                            v
                     Nginx Service
                       /        \
                      v          v
                 Nginx Pod   Nginx Pod
                     |           |
                     +-----+-----+
                           |
                NGINX Prometheus Exporter
                           |
                           v
                       Prometheus
                           |
                           v
                        Grafana


            Логи Kubernetes / Nginx
                       |
                       v
                     Fluentd
                       |
                       v
                      Loki
                       |
                       v
                     Grafana
```

Весь кластер и дополнительные компоненты устанавливаются автоматически с помощью Ansible.

---

## 3. Используемые технологии

| Компонент | Версия |
|---|---|
| OS | Ubuntu 24.04 LTS |
| Kubernetes | 1.37.1 |
| kubeadm | используется для создания кластера |
| containerd | 2.3.6 |
| Calico | 3.33.0 |
| Helm | 4.3.0 |
| Gateway API | 1.6.1 |
| NGINX Gateway Fabric | 2.7.2 |
| Nginx | 1.27 |
| NGINX Prometheus Exporter | 1.5.1 |
| kube-prometheus-stack | 91.8.1 |
| Prometheus | 3.15.0 |
| Loki | 12.0.0 |
| Fluentd | `grafana/fluent-plugin-loki:main` |
| Ansible | используется для автоматизации |

---

## 4. Требования к среде

Для запуска необходимы 3 виртуальные машины:

- `master` — Control Plane Kubernetes
- `worker1` — Worker
- `worker2` — Worker

### Минимальные требования

| Параметр | Значение |
|---|---|
| ОС | Ubuntu 24.04 LTS |
| CPU | 2 ядра |
| RAM (master) | 4 GB |
| RAM (worker) | 2 GB |
| Диск | 20+ GB |
| Интернет | требуется |
| SSH | требуется |

> Решение не зависит от конкретного облачного провайдера.

---

## 5. Подготовка пользователей

Перед запуском Ansible на **всех трёх серверах** необходимо создать пользователя, через которого будет выполняться подключение.

```bash
sudo adduser --disabled-password --gecos "" devops
sudo usermod -aG sudo devops
echo "devops ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/devops
sudo chmod 440 /etc/sudoers.d/devops
```

> Имя пользователя `devops` можно заменить на любое другое. Если используется другое имя, его необходимо указать в `inventory/hosts.ini`.

---

## 6. Настройка SSH

На компьютере, с которого запускается Ansible, создать SSH-ключ:

```bash
ssh-keygen -t ed25519
```

Добавить публичный ключ на все три сервера:

```bash
ssh-copy-id devops@<MASTER_IP>
ssh-copy-id devops@<WORKER1_IP>
ssh-copy-id devops@<WORKER2_IP>
```

Проверка подключения:

```bash
ssh devops@<MASTER_IP>
ssh devops@<WORKER1_IP>
ssh devops@<WORKER2_IP>
```

> SSH должен работать без ввода пароля. Приватный SSH-ключ в репозиторий не добавляется.

---

## 7. Настройка IP-адресов

IP-адреса указываются **только** в файле `inventory/hosts.ini`.

```ini
[master]
master ansible_host=<MASTER_IP> ansible_user=devops

[workers]
worker1 ansible_host=<WORKER1_IP> ansible_user=devops
worker2 ansible_host=<WORKER2_IP> ansible_user=devops

[myVMs:children]
master
workers

[all:vars]
ansible_become=true
```

**Что необходимо изменить:**

| Плейсхолдер | Описание |
|---|---|
| `<MASTER_IP>` | IP мастер-узла |
| `<WORKER1_IP>` | IP первого воркера |
| `<WORKER2_IP>` | IP второго воркера |

Если используется другой пользователь (например `admin`), заменить `ansible_user=devops` на `ansible_user=admin`.

> Другие файлы проекта из-за изменения IP менять не требуется.

---

## 8. Проверка Ansible

После настройки SSH проверить подключение:

```bash
ansible all -m ping
```

Для всех трёх серверов должен быть получен ответ `SUCCESS`. После этого можно запускать развёртывание.

---

## 9. Развёртывание

```bash
./deploy.sh
```

Скрипт автоматически:

- устанавливает необходимые Ansible collections
- подготавливает серверы
- устанавливает Kubernetes и containerd
- создаёт Kubernetes-кластер
- устанавливает Calico
- устанавливает Gateway API
- устанавливает NGINX Gateway Fabric
- разворачивает Nginx
- устанавливает мониторинг
- устанавливает систему логирования

> Ручное создание Kubernetes-ресурсов после запуска не требуется.

---

## 10. Kubernetes

Кластер создаётся с помощью `kubeadm`.

| Компонент | Версия |
|---|---|
| Kubernetes | `1.37.1` |
| Calico (CNI) | `3.33.0` |

Проверить состояние кластера:

```bash
kubectl get nodes
```

Все три узла должны находиться в состоянии `Ready`.

---

## 11. Тестовое приложение

В Kubernetes разворачивается Nginx с двумя репликами в namespace `demo`.

```bash
kubectl get pods -n demo
```

Ожидается два работающих Nginx Pod. Nginx принимает HTTP-запросы и формирует access-логи, которые затем собираются системой логирования.

---

## 12. Gateway API

Для внешнего доступа используется **NGINX Gateway Fabric 2.7.2**.

Используемые ресурсы Gateway API: `GatewayClass`, `Gateway`, `HTTPRoute`.

```
NodePort → Gateway → HTTPRoute → Nginx Service → Nginx Pods
```

> Приложение не публикуется напрямую через собственный NodePort. NodePort используется для доступа к Gateway.

---

## 13. Проверка Gateway API

```bash
# Проверить Gateway
kubectl get gateway -n demo

# Проверить HTTPRoute
kubectl get httproute -n demo
```

Gateway должен иметь состояние `PROGRAMMED=True`.

Проверка приложения:

```bash
curl http://<MASTER_IP>:32630/
```

В ответ должна прийти страница Nginx с HTTP-кодом `200`.

---

## 14. Мониторинг

Используется `kube-prometheus-stack`, который включает:

- Prometheus
- Grafana
- kube-state-metrics
- node-exporter
- Prometheus Operator

Дополнительно для приложения используется **NGINX Prometheus Exporter 1.5.1** — собираются метрики Kubernetes, узлов и Nginx.

---

## 15. Проверка мониторинга

```bash
kubectl get pods -n monitoring
```

Prometheus должен быть в состоянии `Running`.

| Сервис | Адрес |
|---|---|
| Grafana | `http://<MASTER_IP>:30300` |
| Prometheus | `http://<MASTER_IP>:30090` |

Пример запроса Prometheus для количества HTTP-запросов:

```promql
sum(rate(nginx_http_requests_total[5m]))
```

> В проекте настроен `ServiceMonitor`, который автоматически передаёт метрики Nginx в Prometheus.

---

## 16. Grafana

В Grafana автоматически создаются два дополнительных dashboard:

### Kubernetes Overview

Показывает:
- состояние узлов
- CPU и память
- количество и состояние Pod
- HTTP-запросы приложения

### Kubernetes Logging

Показывает логи контейнеров через Loki.

> Помимо кастомных dashboard, доступны стандартные dashboard из kube-prometheus-stack.

---

## 17. Логирование

Для сбора логов используется **Fluentd** в режиме DaemonSet — на каждом узле работает свой экземпляр.

Fluentd получает контейнерные логи из `/var/log/containers/*.log` и передаёт их в Loki.

```
Nginx → container logs → Fluentd → Loki → Grafana
```

Собираются логи HTTP-запросов приложения и другие контейнерные логи Kubernetes.

---

## 18. Loki и проверка логов

| Компонент | Версия |
|---|---|
| Loki | `12.0.0` |

```bash
kubectl get pods -n logging
```

Должны работать Fluentd и Loki.

Для создания нового лога:

```bash
curl http://<MASTER_IP>:32630/
```

После запроса соответствующая запись появляется в Loki. В Grafana открыть dashboard **Kubernetes Logging** и выбрать datasource Loki — в нём будут видны реальные записи Nginx и HTTP-коды ответов.

---

## 19. HTTP-коды и дополнительные метрики

HTTP-коды анализируются из логов через LogQL. Dashboard показывает:

- количество HTTP `2xx`
- количество HTTP `4xx`
- количество HTTP `5xx`
- распределение ответов по кодам

Дополнительно собираются метрики:

- CPU и RAM
- состояние Kubernetes nodes
- количество Pod и состояние Deployment
- HTTP-запросы Nginx

---

## 20. Повторный запуск

Проект поддерживает повторный запуск без ручного вмешательства:

```bash
./deploy.sh
```

### Проверка

```bash
./verify.sh
```

Скрипт проверяет:

- Kubernetes nodes
- Nginx, Service
- Gateway, HTTPRoute
- мониторинг и логирование
- HTTP-доступность приложения

---

## 21. Структура проекта

```
.
├── ansible.cfg
├── inventory/
│   └── hosts.ini
├── collections/
│   └── requirements.yml
├── k8s/
│   └── nginx/
├── playbook.yml
├── deploy.sh
├── verify.sh
└── README.md
```

**Основные Ansible-роли:** `docker`, `kube`, `cluster_up`, `network`, `monitoring`, `logging`

---

## 22. Дополнительные возможности

Помимо обязательных требований реализованы:

- ✅ NGINX Prometheus Exporter
- ✅ ServiceMonitor
- ✅ kube-state-metrics
- ✅ node-exporter
- ✅ Grafana dashboards (Kubernetes Overview + Kubernetes Logging)
- ✅ Централизованный сбор логов через Fluentd
- ✅ Хранение логов в Loki
- ✅ Просмотр логов через Grafana
- ✅ Анализ HTTP-кодов через LogQL
- ✅ Автоматическое создание Grafana datasource
- ✅ Автоматическое создание dashboard

> CI/CD в текущей версии проекта не используется.

---

## 23. Известные ограничения

| Ограничение | Описание |
|---|---|
| Control Plane | Один узел (без HA) |
| Loki | Один экземпляр, без репликации |
| Хранилище | Локальное `hostPath` |
| TLS | Не настроен |
| Load Balancer | Внешний не настроен |
| Alertmanager | Отключён |
| CI/CD | Не реализован |

> Для production-окружения потребовались бы отказоустойчивое хранилище, несколько Control Plane, TLS и резервирование компонентов.

---

## 24. Безопасность

В репозитории **не хранятся**:

- пароли и API-токены
- приватные SSH-ключи
- другие секреты и персональные данные

SSH-ключ создаётся проверяющим самостоятельно и передаётся на сервер только для настройки доступа. IP-адреса тестового окружения указываются только в `inventory/hosts.ini`.

---

## 25. Быстрый запуск

### 1. Подготовить три сервера Ubuntu 24.04

- `master`
- `worker1`
- `worker2`

### 2. Настроить пользователя и SSH

Создать пользователя `devops`, добавить свой SSH-ключ и настроить sudo без пароля:

```bash
sudo adduser --disabled-password --gecos "" devops
sudo usermod -aG sudo devops
echo "devops ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/devops
sudo chmod 440 /etc/sudoers.d/devops
```

### 3. Указать IP-адреса

Отредактировать `inventory/hosts.ini` — заменить `<MASTER_IP>`, `<WORKER1_IP>`, `<WORKER2_IP>`.

### 4. Проверить подключение

```bash
ansible all -m ping
```

### 5. Развернуть проект

```bash
./deploy.sh
```

### 6. Проверить результат

```bash
./verify.sh
```

### 7. Проверить приложение

```bash
curl http://<MASTER_IP>:32630/
```

### 8. Открыть Grafana

```
http://<MASTER_IP>:30300
```

### 9. Проверить Prometheus

```
http://<MASTER_IP>:30090
```

### 10. Проверить логи

В Grafana открыть dashboard **Kubernetes Logging** и выбрать datasource Loki.

---

> После выполнения всех шагов должны быть доступны приложение, мониторинг и централизованный сбор логов.
