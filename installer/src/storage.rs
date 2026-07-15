use serde_json::Value;
use std::collections::BTreeSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

pub const MIN_ALONGSIDE_BYTES: u64 = 64 * 1024 * 1024 * 1024;
pub const MIN_ESP_FREE_BYTES: u64 = 32 * 1024 * 1024;
const ESP_GUID: &str = "c12a7328-f81f-11d2-ba4b-00a0c93ec93b";

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StorageMode {
  EraseDisk,
  AlongsideWindows,
}

impl StorageMode {
  pub fn label(self) -> &'static str {
    match self {
      Self::EraseDisk => "Erase disk",
      Self::AlongsideWindows => "Install alongside Windows",
    }
  }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DiskInfo {
  pub path: String,
  pub size: String,
  pub size_bytes: u64,
  pub model: String,
}

impl DiskInfo {
  pub fn display(&self) -> String {
    format!("{}  {}  {}", self.path, self.size, self.model)
  }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FreeRegion {
  pub start_sector: u64,
  pub end_sector: u64,
  pub size_bytes: u64,
}

impl FreeRegion {
  pub fn display_size(&self) -> String {
    format_gib(self.size_bytes)
  }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AlongsideCandidate {
  pub disk: DiskInfo,
  pub esp_partition: String,
  pub esp_uuid: String,
  pub root_partition_number: u32,
  pub free_region: FreeRegion,
  pub bitlocker_detected: bool,
  pub secure_boot_enabled: bool,
}

impl AlongsideCandidate {
  pub fn display(&self) -> String {
    format!(
      "{}  Windows + {} free",
      self.disk.path,
      self.free_region.display_size()
    )
  }
}

#[derive(Clone, PartialEq, Eq)]
pub enum StoragePlan {
  EraseDisk {
    disk: String,
  },
  AlongsideWindows {
    disk: String,
    disk_size_bytes: u64,
    esp_partition: String,
    esp_uuid: String,
    root_partition_number: u32,
    free_region: FreeRegion,
    bitlocker_detected: bool,
    secure_boot_enabled: bool,
  },
}

impl std::fmt::Debug for StoragePlan {
  fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
    match self {
      Self::EraseDisk { disk } => f.debug_struct("EraseDisk").field("disk", disk).finish(),
      Self::AlongsideWindows {
        disk,
        esp_partition,
        root_partition_number,
        free_region,
        bitlocker_detected,
        secure_boot_enabled,
        ..
      } => f
        .debug_struct("AlongsideWindows")
        .field("disk", disk)
        .field("esp_partition", esp_partition)
        .field("root_partition_number", root_partition_number)
        .field("free_region", free_region)
        .field("bitlocker_detected", bitlocker_detected)
        .field("secure_boot_enabled", secure_boot_enabled)
        .finish(),
    }
  }
}

impl StoragePlan {
  pub fn disk(&self) -> &str {
    match self {
      Self::EraseDisk { disk } | Self::AlongsideWindows { disk, .. } => disk,
    }
  }

}

pub fn detect_disks() -> Vec<DiskInfo> {
  let Ok(output) = Command::new("lsblk")
    .args(["-J", "-b", "-d", "-p", "-o", "PATH,SIZE,MODEL,TYPE,RM,RO"])
    .output()
  else {
    return vec![];
  };

  let live_disk = live_media_disk();
  parse_disks_json(&String::from_utf8_lossy(&output.stdout))
    .into_iter()
    .filter(|disk| live_disk.as_deref() != Some(disk.path.as_str()))
    .collect()
}

pub fn discover_alongside_candidates() -> Vec<AlongsideCandidate> {
  if !Path::new("/sys/firmware/efi").exists() {
    return vec![];
  }

  let secure_boot_enabled = is_secure_boot_enabled();
  detect_disks()
    .into_iter()
    .flat_map(|disk| discover_disk_candidates(&disk, secure_boot_enabled).unwrap_or_default())
    .collect()
}

pub fn validate_alongside_plan(plan: &StoragePlan) -> Result<(), String> {
  let StoragePlan::AlongsideWindows {
    disk,
    disk_size_bytes,
    esp_partition,
    esp_uuid,
    root_partition_number,
    free_region,
    ..
  } = plan
  else {
    return Ok(());
  };

  let candidates = discover_alongside_candidates();
  let valid = candidates.iter().any(|candidate| {
    candidate.disk.path == *disk
      && candidate.disk.size_bytes == *disk_size_bytes
      && candidate.esp_partition == *esp_partition
      && candidate.esp_uuid == *esp_uuid
      && candidate.root_partition_number == *root_partition_number
      && candidate.free_region == *free_region
  });

  if valid {
    Ok(())
  } else {
    Err("The disk layout changed after confirmation. No partition was modified.".into())
  }
}

fn discover_disk_candidates(
  disk: &DiskInfo,
  secure_boot_enabled: bool,
) -> Result<Vec<AlongsideCandidate>, String> {
  let output = Command::new("lsblk")
    .args([
      "-J", "-b", "-p", "-o",
      "PATH,TYPE,FSTYPE,UUID,PARTTYPE,PARTN,MOUNTPOINTS",
      &disk.path,
    ])
    .output()
    .map_err(|e| format!("lsblk failed for {}: {e}", disk.path))?;
  if !output.status.success() {
    return Ok(vec![]);
  }

  let value: Value = serde_json::from_slice(&output.stdout)
    .map_err(|e| format!("Invalid lsblk JSON for {}: {e}", disk.path))?;
  let Some(root) = value.get("blockdevices").and_then(Value::as_array).and_then(|v| v.first()) else {
    return Ok(vec![]);
  };
  let children = root.get("children").and_then(Value::as_array).cloned().unwrap_or_default();
  let bitlocker_detected = children.iter().any(|child| {
    child.get("fstype").and_then(Value::as_str)
      .is_some_and(|v| v.eq_ignore_ascii_case("bitlocker"))
  });

  let Some(esp) = children.iter().find(|child| {
    child.get("parttype").and_then(Value::as_str)
      .is_some_and(|v| v.eq_ignore_ascii_case(ESP_GUID))
  }) else {
    return Ok(vec![]);
  };
  let esp_partition = string_field(esp, "path");
  let esp_uuid = string_field(esp, "uuid");
  if esp_partition.is_empty() || esp_uuid.is_empty() {
    return Ok(vec![]);
  }
  let mountpoints = esp.get("mountpoints").and_then(Value::as_array)
    .map(|values| values.iter().filter_map(Value::as_str).map(str::to_string).collect::<Vec<_>>())
    .unwrap_or_default();
  if !esp_contains_windows(&esp_partition, &mountpoints)? {
    return Ok(vec![]);
  }

  let used_numbers: BTreeSet<u32> = children.iter()
    .filter_map(|child| {
      child.get("partn").and_then(|value| {
        value.as_u64()
          .or_else(|| value.as_str().and_then(|partn| partn.parse().ok()))
          .map(|partn| partn as u32)
      })
    })
    .collect();
  let root_partition_number = (1..=128).find(|n| !used_numbers.contains(n)).unwrap_or(0);
  if root_partition_number == 0 {
    return Ok(vec![]);
  }

  let parted = Command::new("parted")
    .args(["-m", "-s", &disk.path, "unit", "s", "print", "free"])
    .output()
    .map_err(|e| format!("parted failed for {}: {e}", disk.path))?;
  if !parted.status.success() {
    return Ok(vec![]);
  }
  let regions = parse_parted_free(&String::from_utf8_lossy(&parted.stdout));

  Ok(eligible_free_regions(regions).into_iter()
    .map(|free_region| AlongsideCandidate {
      disk: disk.clone(),
      esp_partition: esp_partition.clone(),
      esp_uuid: esp_uuid.clone(),
      root_partition_number,
      free_region,
      bitlocker_detected,
      secure_boot_enabled,
    })
    .collect())
}

fn eligible_free_regions(regions: Vec<FreeRegion>) -> Vec<FreeRegion> {
  regions.into_iter()
    .filter(|region| region.size_bytes >= MIN_ALONGSIDE_BYTES)
    .collect()
}

fn esp_contains_windows(partition: &str, existing_mountpoints: &[String]) -> Result<bool, String> {
  if let Some(mountpoint) = existing_mountpoints.iter().find(|path| !path.is_empty()) {
    return Ok(Path::new(mountpoint).join("EFI/Microsoft/Boot/bootmgfw.efi").is_file()
      && available_bytes(mountpoint) >= MIN_ESP_FREE_BYTES);
  }

  let mount_dir = PathBuf::from(format!("/run/omybuntu-installer/esp-{}", std::process::id()));
  fs::create_dir_all(&mount_dir).map_err(|e| format!("Could not create ESP mountpoint: {e}"))?;
  let mounted = Command::new("mount")
    .args(["-o", "ro", partition, mount_dir.to_string_lossy().as_ref()])
    .stdout(Stdio::null())
    .stderr(Stdio::null())
    .status()
    .map_err(|e| format!("Could not inspect EFI partition {partition}: {e}"))?
    .success();
  if !mounted {
    return Ok(false);
  }
  let found = mount_dir.join("EFI/Microsoft/Boot/bootmgfw.efi").is_file()
    && available_bytes(mount_dir.to_string_lossy().as_ref()) >= MIN_ESP_FREE_BYTES;
  let _ = Command::new("umount").arg(&mount_dir).status();
  let _ = fs::remove_dir(&mount_dir);
  Ok(found)
}

fn available_bytes(path: &str) -> u64 {
  let Ok(output) = Command::new("df").args(["-B1", "--output=avail", path]).output() else {
    return 0;
  };
  String::from_utf8_lossy(&output.stdout)
    .lines()
    .skip(1)
    .find_map(|line| line.trim().parse().ok())
    .unwrap_or(0)
}

fn live_media_disk() -> Option<String> {
  for mountpoint in ["/cdrom", "/run/live/medium"] {
    let source = Command::new("findmnt")
      .args(["-n", "-o", "SOURCE", mountpoint])
      .output()
      .ok()
      .filter(|output| output.status.success())
      .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
      .filter(|source| source.starts_with("/dev/"));
    let Some(source) = source else { continue };
    let parent = Command::new("lsblk")
      .args(["-n", "-p", "-o", "PKNAME", &source])
      .output()
      .ok()
      .filter(|output| output.status.success())
      .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
      .filter(|path| !path.is_empty());
    return parent.or(Some(source));
  }
  None
}

pub fn is_secure_boot_enabled() -> bool {
  let Ok(output) = Command::new("mokutil").arg("--sb-state").output() else {
    return false;
  };
  output.status.success()
    && String::from_utf8_lossy(&output.stdout).to_ascii_lowercase().contains("secureboot enabled")
}

fn string_field(value: &Value, key: &str) -> String {
  value.get(key).and_then(Value::as_str).unwrap_or_default().to_string()
}

fn parse_disks_json(input: &str) -> Vec<DiskInfo> {
  let Ok(value) = serde_json::from_str::<Value>(input) else {
    return vec![];
  };
  value.get("blockdevices").and_then(Value::as_array)
    .into_iter()
    .flatten()
    .filter(|device| string_field(device, "type") == "disk")
    .filter(|device| device.get("rm").and_then(Value::as_bool) != Some(true))
    .filter(|device| device.get("ro").and_then(Value::as_bool) != Some(true))
    .filter_map(|device| {
      let path = string_field(device, "path");
      let size_bytes = device.get("size").and_then(Value::as_u64).unwrap_or(0);
      if path.is_empty() || size_bytes == 0 {
        return None;
      }
      Some(DiskInfo {
        path,
        size: format_gib(size_bytes),
        size_bytes,
        model: string_field(device, "model").trim().to_string(),
      })
    })
    .collect()
}

fn parse_parted_free(input: &str) -> Vec<FreeRegion> {
  let logical_sector = input.lines()
    .find(|line| line.starts_with("/dev/"))
    .and_then(|line| line.trim_end_matches(';').split(':').nth(3))
    .and_then(|value| value.parse::<u64>().ok())
    .unwrap_or(512);

  input.lines()
    .filter(|line| line.trim_end_matches(';').ends_with(":free"))
    .filter_map(|line| {
      let fields: Vec<&str> = line.trim_end_matches(';').split(':').collect();
      if fields.len() < 4 {
        return None;
      }
      let start_sector = fields[1].trim_end_matches('s').parse::<u64>().ok()?;
      let end_sector = fields[2].trim_end_matches('s').parse::<u64>().ok()?;
      let sector_count = end_sector.checked_sub(start_sector)?.checked_add(1)?;
      Some(FreeRegion {
        start_sector,
        end_sector,
        size_bytes: sector_count.saturating_mul(logical_sector),
      })
    })
    .collect()
}

fn format_gib(bytes: u64) -> String {
  let gib = bytes as f64 / (1024.0 * 1024.0 * 1024.0);
  format!("{gib:.1} GiB")
}

#[cfg(test)]
mod tests {
  use super::*;

  #[test]
  fn parses_only_writable_fixed_disks() {
    let input = r#"{
      "blockdevices": [
        {"path":"/dev/nvme0n1","size":536870912000,"model":"Example SSD","type":"disk","rm":false,"ro":false},
        {"path":"/dev/sdb","size":68719476736,"model":"USB","type":"disk","rm":true,"ro":false},
        {"path":"/dev/loop0","size":1024,"model":null,"type":"loop","rm":false,"ro":true}
      ]
    }"#;
    let disks = parse_disks_json(input);
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].path, "/dev/nvme0n1");
    assert_eq!(disks[0].size, "500.0 GiB");
  }

  #[test]
  fn parses_all_parted_free_regions_in_sector_units() {
    let input = "BYT;\n/dev/nvme0n1:1000000s:nvme:512:4096:gpt:Disk:;\n1:2048s:206847s:204800s:fat32:EFI:boot, esp;\n:206848s:406847s:200000s:free;\n:500000s:900000s:400001s:free;\n";
    let regions = parse_parted_free(input);
    assert_eq!(regions.len(), 2);
    assert_eq!(regions[0].start_sector, 206848);
    assert_eq!(regions[0].size_bytes, 200000 * 512);
    assert_eq!(regions[1].end_sector, 900000);
  }

  #[test]
  fn storage_plan_redacts_unrelated_fields_and_reports_mode() {
    let plan = StoragePlan::AlongsideWindows {
      disk: "/dev/nvme0n1".into(),
      disk_size_bytes: 1,
      esp_partition: "/dev/nvme0n1p1".into(),
      esp_uuid: "ABCD".into(),
      root_partition_number: 4,
      free_region: FreeRegion { start_sector: 10, end_sector: 20, size_bytes: 11 * 512 },
      bitlocker_detected: true,
      secure_boot_enabled: true,
    };
    assert!(matches!(plan, StoragePlan::AlongsideWindows { .. }));
    assert_eq!(plan.disk(), "/dev/nvme0n1");
  }

  #[test]
  fn requires_at_least_64_gib_of_contiguous_free_space() {
    let regions = vec![
      FreeRegion { start_sector: 1, end_sector: 2, size_bytes: MIN_ALONGSIDE_BYTES - 1 },
      FreeRegion { start_sector: 3, end_sector: 4, size_bytes: MIN_ALONGSIDE_BYTES },
    ];
    let eligible = eligible_free_regions(regions);
    assert_eq!(eligible.len(), 1);
    assert_eq!(eligible[0].size_bytes, MIN_ALONGSIDE_BYTES);
  }
}
