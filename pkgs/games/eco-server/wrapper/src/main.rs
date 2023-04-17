use anyhow::{Context, Result};
use clap::{Parser, ValueHint};
use nix::mount::{mount, MsFlags};
use nix::sched::{unshare, CloneFlags};
use nix::unistd::{getgid, getuid};
use std::os::unix::{fs::PermissionsExt, process::CommandExt};
use std::path::{Path, PathBuf};
use std::process::Command;

static ECO_SERVER_FILE: &str = "EcoServer";
static ECO_DEFAULT_WORLD_FILE: &str = "DefaultWorld";
static ECO_CONFIGS_DIRECTORY: &str = "Configs";
static ECO_MODS_DIRECTORY: &str = "Mods";
static ECO_MODS_CORE_DIRECTORY: &str = "Mods/__core__";
static ECO_MODS_INTEGRATION_FILE: &str = "Mods/Eco.IntegrationTests.dll";
static ECO_WEBCLIENT_DIRECTORY: &str = "WebClient";
static ECO_WEBCLIENT_WEBBIN_DIRECTORY: &str = "WebClient/WebBin";
static ECO_WEBCLIENT_WEBBIN_LAYERS_DIRECTORY: &str = "WebClient/WebBin/Layers";

#[derive(Parser, Debug)]
struct Args {
    /// Directory with Eco server installation.
    #[clap(short, long, value_hint = ValueHint::DirPath)]
    server_dir: PathBuf,

    /// Directory for Eco server configuration and data. If not set, current
    /// working directory is used.
    #[clap(short, long, value_hint = ValueHint::DirPath)]
    data_dir: Option<PathBuf>,

    #[clap(short, long, hide = true, default_value = ECO_SERVER_FILE)]
    executable: PathBuf,

    #[clap(short, long, hide = true)]
    argv0: Option<String>,

    /// Command-line arguments to pass to the Eco server.
    #[clap(trailing_var_arg = true)]
    server_args: Vec<String>,
}

fn main() -> Result<()> {
    let args = Args::parse();

    let argv0 = args
        .argv0
        .unwrap_or_else(|| std::env::args().next().unwrap_or("EcoServer".to_string()));

    let data_dir = match args.data_dir {
        Some(dir) => {
            std::fs::create_dir_all(&dir).with_context(|| {
                format!(
                    "Create intermediate directories for {}",
                    dir.to_string_lossy(),
                )
            })?;
            dir
        }
        None => PathBuf::from("."),
    };

    unshare_namespaces()?;
    prepare_server(&args.server_dir, &data_dir).context("Prepare server executable binding")?;
    prepare_mods(&args.server_dir, &data_dir).context("Prepare mods directory binding")?;
    prepare_webclient(&args.server_dir, &data_dir).context("Prepare web client bindings")?;
    prepare_configs(&args.server_dir, &data_dir).context("Prepare configuration directory")?;

    let program = if args.executable.is_relative() {
        data_dir.join(args.executable)
    } else {
        args.executable
    };
    let program =
        std::fs::canonicalize(program).context("Failed to canonicalize executable path")?;

    let err = Command::new(program.clone())
        .arg0(argv0)
        .args(args.server_args)
        .current_dir(data_dir)
        .exec();

    Err(err).context(format!("Failed to execute {}", program.to_string_lossy()))
}

fn unshare_namespaces() -> Result<()> {
    let uid = getuid();
    let gid = getgid();

    let mut namespaces = CloneFlags::CLONE_NEWNS;
    if !uid.is_root() {
        namespaces |= CloneFlags::CLONE_NEWUSER;
    }

    unshare(namespaces).context("Failed to unshare namespaces")?;

    if uid.is_root() {
        return Ok(());
    }

    std::fs::write("/proc/self/setgroups", "deny").context("Failed to deny setgroups")?;
    std::fs::write("/proc/self/uid_map", format!("{0} {0} 1", uid))
        .context("Failed to write user ID map")?;
    std::fs::write("/proc/self/gid_map", format!("{0} {0} 1", gid))
        .context("Failed to write group ID map")?;

    Ok(())
}

fn prepare_server(server_dir: &Path, data_dir: &Path) -> Result<()> {
    let source = server_dir.join(ECO_SERVER_FILE);
    let target = data_dir.join(ECO_SERVER_FILE);

    create_file(&target)?;

    mount_bind(&source, &target)
}

fn prepare_mods(server_dir: &Path, data_dir: &Path) -> Result<()> {
    create_dir(&data_dir.join(ECO_MODS_DIRECTORY))?;

    prepare_mods_core(server_dir, data_dir)?;
    prepare_mods_integration(server_dir, data_dir)
}

fn prepare_mods_core(server_dir: &Path, data_dir: &Path) -> Result<()> {
    let source = server_dir.join(ECO_MODS_CORE_DIRECTORY);
    let target = data_dir.join(ECO_MODS_CORE_DIRECTORY);

    create_dir(&target)?;

    mount_bind(&source, &target)
}

fn prepare_mods_integration(server_dir: &Path, data_dir: &Path) -> Result<()> {
    let source = server_dir.join(ECO_MODS_INTEGRATION_FILE);
    let target = data_dir.join(ECO_MODS_INTEGRATION_FILE);

    create_file(&target)?;

    mount_bind(&source, &target)
}

fn prepare_webclient(server_dir: &Path, data_dir: &Path) -> Result<()> {
    let source = server_dir.join(ECO_WEBCLIENT_DIRECTORY);
    let target = data_dir.join(ECO_WEBCLIENT_DIRECTORY);

    create_dir(&target)?;

    // We mount our WebClient/WebBin/Layers on top of the server's WebClient,
    // and then mount source WebClient with recursive bind. This is
    // necessary since Eco writes some images there, but the directory is
    // otherwise immutable.
    prepare_webclient_webbin(server_dir, data_dir)?;

    mount_rbind(&source, &target)
}

fn prepare_webclient_webbin(server_dir: &Path, data_dir: &Path) -> Result<()> {
    create_dir(&data_dir.join(ECO_WEBCLIENT_WEBBIN_DIRECTORY))?;

    let source = data_dir.join(ECO_WEBCLIENT_WEBBIN_LAYERS_DIRECTORY);
    let target = server_dir.join(ECO_WEBCLIENT_WEBBIN_LAYERS_DIRECTORY);

    create_dir(&source)?;

    mount_bind(&source, &target)
}

fn prepare_configs(server_dir: &Path, data_dir: &Path) -> Result<()> {
    let source = server_dir.join(ECO_CONFIGS_DIRECTORY);
    let target = data_dir.join(ECO_CONFIGS_DIRECTORY);

    if target.try_exists()? {
        return Ok(());
    }

    let _ = copy_dir::copy_dir(source, &target)?;

    let mut perms = std::fs::metadata(&target)?.permissions();
    perms.set_mode(perms.mode() | 0o700); // add all permissions for owner
    std::fs::set_permissions(&target, perms)?;

    prepare_default_world(server_dir, data_dir)
}

fn prepare_default_world(server_dir: &Path, data_dir: &Path) -> Result<()> {
    let source = server_dir.join(ECO_DEFAULT_WORLD_FILE);
    let target = data_dir.join(ECO_DEFAULT_WORLD_FILE);

    if target.try_exists()? {
        return Ok(());
    }

    let _ = std::fs::copy(source, target)?;

    Ok(())
}

fn create_file(path: &Path) -> Result<()> {
    let _ = std::fs::OpenOptions::new()
        .append(true)
        .create(true)
        .open(path)?;
    Ok(())
}

fn create_dir(path: &Path) -> Result<()> {
    match std::fs::create_dir(path) {
        Ok(_) => Ok(()),
        Err(e) => match e.kind() {
            std::io::ErrorKind::AlreadyExists => Ok(()),
            _ => Err(e.into()),
        },
    }
}

fn mount_bind(source: &Path, target: &Path) -> Result<()> {
    mount_bind_with_flags(source, target, MsFlags::empty())
}

fn mount_rbind(source: &Path, target: &Path) -> Result<()> {
    mount_bind_with_flags(source, target, MsFlags::MS_REC)
}

fn mount_bind_with_flags(source: &Path, target: &Path, flags: MsFlags) -> Result<()> {
    let none = None::<&str>;
    mount(Some(source), target, none, MsFlags::MS_BIND | flags, none)?;
    Ok(())
}
