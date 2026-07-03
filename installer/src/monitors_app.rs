#![allow(dead_code)]
use std::process::Command;
use serde::Deserialize;
use crossterm::event::{KeyCode, KeyEvent};

#[derive(Deserialize, Debug, Clone)]
#[serde(rename_all = "camelCase")]
pub struct Monitor {
    pub id: i32,
    pub name: String,
    pub description: String,
    pub make: String,
    pub model: String,
    pub width: i32,
    pub height: i32,
    pub refresh_rate: f64,
    pub x: i32,
    pub y: i32,
    pub scale: f64,
    pub transform: i32,
    pub focused: bool,
    pub disabled: bool,
    pub mirror_of: String,
    pub available_modes: Vec<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MenuState {
    Main,
    MonitorSelected,
    ChangeResolution,
    ChangeScale,
    ChangePosition,
    ChangeRotation,
}

pub struct Translations {
    pub title: &'static str,
    pub select_action: &'static str,
    pub conf_monitor: &'static str,
    pub active: &'static str,
    pub focused: &'static str,
    pub disabled: &'static str,
    pub mirroring: &'static str,
    pub resolution: &'static str,
    pub scale: &'static str,
    pub position: &'static str,
    pub rotation: &'static str,
    pub enable: &'static str,
    pub disable: &'static str,
    pub back: &'static str,
    pub preset_mirror: &'static str,
    pub preset_extend: &'static str,
    pub preset_screen1: &'static str,
    pub preset_screen2: &'static str,
    pub select_res: &'static str,
    pub select_scale: &'static str,
    pub select_pos: &'static str,
    pub select_rot: &'static str,
    pub left_of: &'static str,
    pub right_of: &'static str,
    pub above: &'static str,
    pub below: &'static str,
    pub normal: &'static str,
    pub rot_90: &'static str,
    pub rot_180: &'static str,
    pub rot_270: &'static str,
    pub exit: &'static str,
    pub help_text: &'static str,
    pub label_port: &'static str,
    pub label_model: &'static str,
    pub label_res: &'static str,
    pub label_scale: &'static str,
    pub label_pos: &'static str,
    pub label_rot: &'static str,
    pub label_status: &'static str,
    pub label_mirroring: &'static str,
}

impl Translations {
    pub fn get(lang: &str) -> Self {
        if lang.starts_with("pt") {
            Self {
                title: "GESTOR DE MONITORES",
                select_action: "Selecione uma ação:",
                conf_monitor: "Configurar Monitor {} ({})",
                active: "ATIVO",
                focused: "FOCADO",
                disabled: "DESATIVADO",
                mirroring: "ESPELHANDO {}",
                resolution: "Alterar Resolução",
                scale: "Alterar Escala",
                position: "Alterar Posição",
                rotation: "Alterar Rotação",
                enable: "Ativar Monitor",
                disable: "Desativar Monitor",
                back: "Voltar ao Menu Principal",
                preset_mirror: "Espelhar (Mirror)",
                preset_extend: "Estender (Extend)",
                preset_screen1: "Tela 1 apenas",
                preset_screen2: "Tela 2 apenas",
                select_res: "Selecione uma resolução:",
                select_scale: "Selecione uma escala:",
                select_pos: "Selecione uma posição:",
                select_rot: "Selecione uma rotação:",
                left_of: "Esquerda de",
                right_of: "Direita de",
                above: "Acima de",
                below: "Abaixo de",
                normal: "Normal (0)",
                rot_90: "90° (1)",
                rot_180: "180° (2)",
                rot_270: "270° (3)",
                exit: "Sair",
                help_text: "←/→: Navegar | Enter: Configurar | M: Espelhar | X: Estender | 1: Tela 1 | 2: Tela 2 | Esc/Q: Sair",
                label_port: "Porta",
                label_model: "Modelo",
                label_res: "Res",
                label_scale: "Escala",
                label_pos: "Pos",
                label_rot: "Rot",
                label_status: "Status",
                label_mirroring: "Espelhando",
            }
        } else if lang.starts_with("es") {
            Self {
                title: "GESTIÓN DE MONITORES",
                select_action: "Seleccione una acción:",
                conf_monitor: "Configurar Monitor {} ({})",
                active: "ACTIVO",
                focused: "EN FOCO",
                disabled: "DESACTIVADO",
                mirroring: "DUPLICANDO {}",
                resolution: "Cambiar Resolución",
                scale: "Cambiar Escala",
                position: "Cambiar Posición",
                rotation: "Cambiar Rotación",
                enable: "Activar Monitor",
                disable: "Desactivar Monitor",
                back: "Volver al Menú Principal",
                preset_mirror: "Duplicar (Mirror)",
                preset_extend: "Extender (Extend)",
                preset_screen1: "Solo pantalla 1",
                preset_screen2: "Solo pantalla 2",
                select_res: "Seleccione una resolución:",
                select_scale: "Seleccione una escala:",
                select_pos: "Seleccione una posición:",
                select_rot: "Seleccione una rotación:",
                left_of: "Izquierda de",
                right_of: "Derecha de",
                above: "Encima de",
                below: "Debajo de",
                normal: "Normal (0)",
                rot_90: "90° (1)",
                rot_180: "180° (2)",
                rot_270: "270° (3)",
                exit: "Salir",
                help_text: "←/→: Navegar | Enter: Configurar | M: Duplicar | X: Extender | 1: Pantalla 1 | 2: Pantalla 2 | Esc/Q: Salir",
                label_port: "Puerto",
                label_model: "Modelo",
                label_res: "Res",
                label_scale: "Escala",
                label_pos: "Pos",
                label_rot: "Rot",
                label_status: "Estado",
                label_mirroring: "Duplicando",
            }
        } else {
            Self {
                title: "MONITOR MANAGEMENT",
                select_action: "Select action:",
                conf_monitor: "Configure Monitor {} ({})",
                active: "ACTIVE",
                focused: "FOCUSED",
                disabled: "DISABLED",
                mirroring: "MIRRORING {}",
                resolution: "Change Resolution",
                scale: "Change Scale",
                position: "Change Position",
                rotation: "Change Rotation",
                enable: "Enable Monitor",
                disable: "Disable Monitor",
                back: "Back to Main Menu",
                preset_mirror: "Mirror",
                preset_extend: "Extend",
                preset_screen1: "Screen 1 only",
                preset_screen2: "Screen 2 only",
                select_res: "Select a resolution:",
                select_scale: "Select a scale:",
                select_pos: "Select a position:",
                select_rot: "Select a rotation:",
                left_of: "Left of",
                right_of: "Right of",
                above: "Above",
                below: "Below",
                normal: "Normal (0)",
                rot_90: "90° (1)",
                rot_180: "180° (2)",
                rot_270: "270° (3)",
                exit: "Exit",
                help_text: "←/→: Navigate | Enter: Configure | M: Mirror | X: Extend | 1: Screen 1 | 2: Screen 2 | Esc/Q: Exit",
                label_port: "Port",
                label_model: "Model",
                label_res: "Res",
                label_scale: "Scale",
                label_pos: "Pos",
                label_rot: "Rot",
                label_status: "Status",
                label_mirroring: "Mirroring",
            }
        }
    }
}

pub struct App {
    pub monitors: Vec<Monitor>,
    pub selected_idx: usize,
    pub should_quit: bool,
    pub current_menu: MenuState,
    pub selected_sub_idx: usize,
    
    // Submenu options lists
    pub resolutions: Vec<String>,
    pub scales: Vec<String>,
    pub positions: Vec<String>,
    pub rotations: Vec<String>,
    
    // Configs
    pub translations: Translations,
    pub lang: String,
}

impl App {
    pub fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let lang = Self::get_language();
        let translations = Translations::get(&lang);
        
        let mut app = Self {
            monitors: Vec::new(),
            selected_idx: 0,
            should_quit: false,
            current_menu: MenuState::Main,
            selected_sub_idx: 0,
            resolutions: Vec::new(),
            scales: Vec::new(),
            positions: Vec::new(),
            rotations: Vec::new(),
            translations,
            lang,
        };
        
        app.refresh_monitors()?;
        Ok(app)
    }
    
    fn get_language() -> String {
        if let Ok(val) = std::env::var("OMYBUNTU_LANGUAGE") {
            if !val.is_empty() {
                return val;
            }
        }
        let config_path = format!("{}/.config/omybuntu/language", std::env::var("HOME").unwrap_or_default());
        std::fs::read_to_string(config_path)
            .map(|s| s.trim().to_string())
            .unwrap_or_else(|_| "en".to_string())
    }
    
    pub fn refresh_monitors(&mut self) -> Result<(), Box<dyn std::error::Error>> {
        let output = Command::new("hyprctl")
            .args(["monitors", "all", "-j"])
            .output()?;
            
        let mut monitors: Vec<Monitor> = serde_json::from_slice(&output.stdout)?;
        
        // Sort internal first, then by ID
        monitors.sort_by(|a, b| {
            let a_edp = a.name.contains("eDP");
            let b_edp = b.name.contains("eDP");
            if a_edp && !b_edp {
                std::cmp::Ordering::Less
            } else if !a_edp && b_edp {
                std::cmp::Ordering::Greater
            } else {
                a.id.cmp(&b.id)
            }
        });
        
        self.monitors = monitors;
        if self.selected_idx >= self.monitors.len() {
            self.selected_idx = 0;
        }
        Ok(())
    }
    
    pub fn total_main_options(&self) -> usize {
        self.monitors.len()
    }
    
    fn run_helper(&self, args: &[&str]) -> Result<(), Box<dyn std::error::Error>> {
        let helper_cmd = if let Ok(val) = std::env::var("OMYBUNTU_PATH") {
            format!("{}/bin/omybuntu-hyprland-monitor-helper", val)
        } else {
            "omybuntu-hyprland-monitor-helper".to_string()
        };
        
        Command::new(helper_cmd)
            .args(args)
            .output()?;
        Ok(())
    }
    
    pub fn handle_key(&mut self, key: KeyEvent) -> Result<bool, Box<dyn std::error::Error>> {
        match self.current_menu {
            MenuState::Main => self.handle_key_main(key),
            MenuState::MonitorSelected => self.handle_key_monitor_selected(key),
            MenuState::ChangeResolution => self.handle_key_submenu(key, &self.resolutions.clone()),
            MenuState::ChangeScale => self.handle_key_submenu(key, &self.scales.clone()),
            MenuState::ChangePosition => self.handle_key_submenu(key, &self.positions.clone()),
            MenuState::ChangeRotation => self.handle_key_submenu(key, &self.rotations.clone()),
        }
    }
    
    fn handle_key_main(&mut self, key: KeyEvent) -> Result<bool, Box<dyn std::error::Error>> {
        let total = self.monitors.len();
        if total == 0 {
            return Ok(false);
        }
        
        match key.code {
            KeyCode::Up | KeyCode::Left | KeyCode::Char('k') | KeyCode::Char('h') | KeyCode::BackTab => {
                if self.selected_idx > 0 {
                    self.selected_idx -= 1;
                } else {
                    self.selected_idx = total - 1;
                }
            }
            KeyCode::Down | KeyCode::Right | KeyCode::Char('j') | KeyCode::Char('l') | KeyCode::Tab => {
                if self.selected_idx < total - 1 {
                    self.selected_idx += 1;
                } else {
                    self.selected_idx = 0;
                }
            }
            KeyCode::Enter => {
                self.current_menu = MenuState::MonitorSelected;
                self.selected_sub_idx = 0;
            }
            KeyCode::Char('m') | KeyCode::Char('M') => {
                let _ = self.run_helper(&["project", "mirror"]);
                self.refresh_monitors()?;
            }
            KeyCode::Char('x') | KeyCode::Char('X') => {
                let _ = self.run_helper(&["project", "extend"]);
                self.refresh_monitors()?;
            }
            KeyCode::Char('1') => {
                let _ = self.run_helper(&["project", "screen1"]);
                self.refresh_monitors()?;
            }
            KeyCode::Char('2') => {
                let _ = self.run_helper(&["project", "screen2"]);
                self.refresh_monitors()?;
            }
            KeyCode::Esc | KeyCode::Char('q') | KeyCode::Char('Q') => {
                self.should_quit = true;
                return Ok(true);
            }
            _ => {}
        }
        Ok(false)
    }
    
    fn handle_key_monitor_selected(&mut self, key: KeyEvent) -> Result<bool, Box<dyn std::error::Error>> {
        let monitor = &self.monitors[self.selected_idx].clone();
        
        let mut opts = Vec::new();
        if monitor.disabled {
            opts.push(self.translations.enable);
        } else {
            opts.push(self.translations.resolution);
            opts.push(self.translations.scale);
            opts.push(self.translations.position);
            opts.push(self.translations.rotation);
            opts.push(self.translations.disable);
        }
        opts.push(self.translations.back);
        
        let total = opts.len();
        
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                if self.selected_sub_idx > 0 {
                    self.selected_sub_idx -= 1;
                } else {
                    self.selected_sub_idx = total - 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.selected_sub_idx < total - 1 {
                    self.selected_sub_idx += 1;
                } else {
                    self.selected_sub_idx = 0;
                }
            }
            KeyCode::Esc => {
                self.current_menu = MenuState::Main;
            }
            KeyCode::Enter => {
                let choice = opts[self.selected_sub_idx];
                if choice == self.translations.back {
                    self.current_menu = MenuState::Main;
                } else if choice == self.translations.enable {
                    let _ = self.run_helper(&["set", &monitor.name, "preferred", "auto", "1.0", "0"]);
                    self.refresh_monitors()?;
                    self.current_menu = MenuState::Main;
                } else if choice == self.translations.disable {
                    let _ = self.run_helper(&["set", &monitor.name, "disable", "auto", "1.0", "0"]);
                    self.refresh_monitors()?;
                    self.current_menu = MenuState::Main;
                } else if choice == self.translations.resolution {
                    self.resolutions = vec!["preferred".to_string(), "auto".to_string()];
                    self.resolutions.extend(monitor.available_modes.clone());
                    self.current_menu = MenuState::ChangeResolution;
                    self.selected_sub_idx = 0;
                } else if choice == self.translations.scale {
                    self.scales = vec![
                        "1".to_string(),
                        "1.25".to_string(),
                        "1.5".to_string(),
                        "1.6".to_string(),
                        "2".to_string(),
                        "3".to_string(),
                        "4".to_string(),
                    ];
                    self.current_menu = MenuState::ChangeScale;
                    self.selected_sub_idx = 0;
                } else if choice == self.translations.position {
                    self.positions = vec!["auto".to_string()];
                    for m in &self.monitors {
                        if m.name != monitor.name {
                            self.positions.push(format!("left_of:{}", m.name));
                            self.positions.push(format!("right_of:{}", m.name));
                            self.positions.push(format!("above:{}", m.name));
                            self.positions.push(format!("below:{}", m.name));
                        }
                    }
                    self.current_menu = MenuState::ChangePosition;
                    self.selected_sub_idx = 0;
                } else if choice == self.translations.rotation {
                    self.rotations = vec![
                        "0".to_string(),
                        "1".to_string(),
                        "2".to_string(),
                        "3".to_string(),
                    ];
                    self.current_menu = MenuState::ChangeRotation;
                    self.selected_sub_idx = 0;
                }
            }
            _ => {}
        }
        Ok(false)
    }
    
    fn handle_key_submenu(&mut self, key: KeyEvent, opts: &[String]) -> Result<bool, Box<dyn std::error::Error>> {
        let total = opts.len();
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                if self.selected_sub_idx > 0 {
                    self.selected_sub_idx -= 1;
                } else {
                    self.selected_sub_idx = total - 1;
                }
            }
            KeyCode::Down | KeyCode::Char('j') => {
                if self.selected_sub_idx < total - 1 {
                    self.selected_sub_idx += 1;
                } else {
                    self.selected_sub_idx = 0;
                }
            }
            KeyCode::Esc => {
                self.current_menu = MenuState::MonitorSelected;
                self.selected_sub_idx = 0;
            }
            KeyCode::Enter => {
                let val = &opts[self.selected_sub_idx];
                let monitor = &self.monitors[self.selected_idx];
                
                let cur_mode = if monitor.width == 0 {
                    "preferred".to_string()
                } else {
                    format!("{}x{}@{}", monitor.width, monitor.height, monitor.refresh_rate.round())
                };
                let cur_pos = format!("{}x{}", monitor.x, monitor.y);
                
                match self.current_menu {
                    MenuState::ChangeResolution => {
                        let _ = self.run_helper(&[
                            "set",
                            &monitor.name,
                            val,
                            &cur_pos,
                            &monitor.scale.to_string(),
                            &monitor.transform.to_string(),
                        ]);
                    }
                    MenuState::ChangeScale => {
                        let _ = self.run_helper(&[
                            "set",
                            &monitor.name,
                            &cur_mode,
                            &cur_pos,
                            val,
                            &monitor.transform.to_string(),
                        ]);
                    }
                    MenuState::ChangePosition => {
                        let _ = self.run_helper(&[
                            "set",
                            &monitor.name,
                            &cur_mode,
                            val,
                            &monitor.scale.to_string(),
                            &monitor.transform.to_string(),
                        ]);
                    }
                    MenuState::ChangeRotation => {
                        let _ = self.run_helper(&[
                            "set",
                            &monitor.name,
                            &cur_mode,
                            &cur_pos,
                            &monitor.scale.to_string(),
                            val,
                        ]);
                    }
                    _ => {}
                }
                
                self.refresh_monitors()?;
                self.current_menu = MenuState::Main;
                self.selected_sub_idx = 0;
            }
            _ => {}
        }
        Ok(false)
    }
}
