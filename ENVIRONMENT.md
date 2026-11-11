# Entorno de desarrollo (Docker + Conda, sin Nix)

Entornos **Conda (miniforge3)** aislados por capítulo, expuestos por **SSH**.
Cada capítulo del libro tiene su propio `envs/chapterNN.yml` y su propia imagen,
así las dependencias que chocan entre capítulos nunca conviven. Es una instancia
del template [`dev-conda-env`](https://github.com/anomalyco/opencode) (repo
hermano, `ToEdit_`).

## Prerequisitos

- Docker y Docker Compose.
- Una clave SSH: `~/.ssh/id_ed25519` (y su `.pub`).

## Quickstart

```sh
./build.sh envs/chapter01.yml     # construye la imagen mlewp-chapter01
./setup.sh envs/chapter01.yml     # arranca el contenedor + instala tu clave
ssh mlewp                         # repo montado en /home/dev/project
```

Añade una vez a `~/.ssh/config` (mismo Host para todos los capítulos: solo uno
corre a la vez, todos en el puerto 2222):

```
Host mlewp
    HostName 127.0.0.1
    User dev
    Port 2222
    IdentityFile ~/.ssh/id_ed25519
```

## Flujo

```sh
./build.sh envs/chapter06.yml        # build
./setup.sh envs/chapter06.yml        # up + clave
ssh mlewp                            # entrar

docker compose exec dev python ...   # comando directo (usa .env)
docker compose down                  # parar y eliminar
```

- Solo **un capítulo** corre a la vez (puerto único `2222` y un único volumen
  `positron-server` compartido). Para cambiar de capítulo: `docker compose down`
  y luego `./setup.sh envs/<otro>.yml`.
- `build.sh`/`setup.sh` escriben el estado resuelto en `.env` (generado, no se
  commitea), por eso `docker compose exec/down/logs` funcionan sin exportar nada.
- Los nombres de imagen/contenedor derivan de `PROJECT_NAME` (`mlewp`) y del
  nombre del archivo: `envs/chapter06.yml` → `mlewp-chapter06:latest`.

## Positron (Remote SSH)

El contenedor solo admite login del usuario **`dev`** (`PermitRootLogin no`,
solo autenticación por clave). Para Positron:

1. Conecta al host **`mlewp`** (paleta → "Remote-SSH: Connect to Host" →
   `mlewp`), que en `~/.ssh/config` usa `User dev`.
2. **No** uses un host que apunte a `root` en el puerto `2222` (p. ej.
   `NycTaxi`, `ProyectoDemoBiblioteca`, `DriverHypertensionRisk`): con `root`
   la conexión falla con "Too many authentication failures".
3. El servidor remoto (REH) se descarga en el volumen `~/.positron-server`
   (compartido, ya con permisos para `dev`).
4. En la terminal de Positron, `python` resuelve al entorno del capítulo
   (Python 3.10), **no** a `base` (3.12). Si ves el prompt `(base)` o un
   `python` 3.12, es un contenedor viejo: re-ejecuta `./build.sh envs/chapterNN.yml`
   (ver "Gotchas": el `.bashrc` de `dev` se corrige para activar `current`).

> Cuidado con los puertos: varios Host de `~/.ssh/config` apuntan a
> `127.0.0.1:2222`. Solo uno puede usar ese puerto a la vez; para correr varios
> proyectos en paralelo, asígnale a cada uno su propio puerto.

## Capítulos

| Cap | Env | Paquetes clave | Notas |
| --- | --- | --- | --- |
| 1 | `mlewp-chapter01` | sklearn, pandas, matplotlib, kaggle, prophet | validado |
| 2 | `mlewp-chapter02` | sklearn, jupyter, prophet, poetry, pytest, kaggle | |
| 3 | `mlewp-chapter03` | mlflow, pyspark, optuna, hyperopt, evidently, alibi-detect | `auto-sklearn`/`smac` omitidos (requieren `scikit-learn<1.3`) |
| 4 | `mlewp-chapter04` | pytest, bandit, safety, coverage, poetry | cap. de packaging |
| 5 | `mlewp-chapter05` | apache-airflow, zenml, kfp | k8s/docker pendiente |
| 6 | `mlewp-chapter06` | pyspark, ray, xgboost, mlflow, fastapi | k8s/docker pendiente |
| 7 | `mlewp-chapter07` | torch (CPU), transformers, langchain, openai, datasets | |
| 8 | `mlewp-chapter08` | mlflow, flask, fastapi, shap | `kubectl`/`kind` pendiente |
| 9 | `mlewp-chapter09` | apache-airflow + providers, pyspark, langchain, boto3 | Airflow necesita constraints |

## Gotchas

- **Yml normalizados a Linux.** Los `mlewp-chapterNN.yml` del autor están
  exportados en macOS arm64 (`file://`, wheels `macosx_*`, `appnope`, `xattr`).
  Los `envs/chapterNN.yml` de aquí están limpios para Linux/conda-forge.
- **`current` symlink.** La imagen crea `/opt/conda/envs/current` apuntando al
  entorno del capítulo; por eso el contenedor es genérico e independiente del
  `name:` del yml.
- **`useradd -p '*'`.** El usuario `dev` usa `*` en shadow (no `!`), para que
  `sshd` permita login por clave pero no por password.
- **`.bashrc` de `dev`.** El image miniforge3 deja en `.bashrc` un
  `conda activate base` (Python 3.12); el Dockerfile lo reemplaza por un
  `export PATH` a `/opt/conda/envs/current/bin`, para que la terminal (Positron)
  use el entorno del capítulo (3.10).
- **Solo `publickey`.** `sshd_config` deshabilita `PasswordAuthentication` y
  `KbdInteractiveAuthentication`, así el cliente ssh2 de Positron no hace loop
  ni agota los intentos de autenticación.
- **Herramientas para Positron.** La imagen incluye `curl`, `unzip` y `tar`
  (requisitos del bootstrap del servidor remoto).
- **Airflow 2.7** (Ch5/Ch9) necesita su constraints para resolver; instrucción
  en el comentario del yml.
- **Kubernetes / Docker** (Ch5/6/8/9): falta cablear `kubectl`/`kind` y montar
  `/var/run/docker.sock` en esos capítulos.
- **`.env`** es generado por los scripts (gitignored); el template documenta las
  variables en `.env.example`.

## Modificar un entorno

Edita `envs/chapterNN.yml` y re-ejecuta `./build.sh envs/chapterNN.yml` (el
layer caching solo recompila lo que cambió). Prefiere **conda** (conda-forge)
para binarios nativos (`numpy`, `pandas`, `scikit-learn`, `prophet`, `pyspark`,
`torch`, `tensorflow`, `ray`, `xgboost`, `mlflow`, `kaggle`) y deja lo
pure-python bajo `pip:`.
