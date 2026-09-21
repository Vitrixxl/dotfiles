//! Accès à NetworkManager via `nmcli`. Tout est bloquant : à appeler depuis
//! l'exécuteur d'arrière-plan, jamais depuis le thread UI.

use std::collections::HashMap;
use std::process::Command;

#[derive(Clone, Debug, PartialEq)]
pub struct Network {
    pub ssid: String,
    /// 0–100, tel que rapporté par NetworkManager.
    pub signal: u8,
    /// Vide pour un réseau ouvert, sinon p. ex. "WPA2", "WPA2 WPA3".
    pub security: String,
    pub in_use: bool,
    /// UUID du profil enregistré pour ce SSID, s'il existe.
    pub profile: Option<String>,
}

impl Network {
    pub fn is_open(&self) -> bool {
        self.security.is_empty()
    }

    pub fn is_enterprise(&self) -> bool {
        self.security.contains("802.1X")
    }

    /// Nombre de barres (1–4) ; sert aussi de clé de tri pour que la liste
    /// ne saute pas à chaque petite variation du signal.
    pub fn bars(&self) -> u8 {
        match self.signal {
            0..=29 => 1,
            30..=54 => 2,
            55..=74 => 3,
            _ => 4,
        }
    }
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct State {
    pub iface: Option<String>,
    pub enabled: bool,
    pub networks: Vec<Network>,
}

fn nmcli(args: &[&str]) -> Result<String, String> {
    let out = Command::new("nmcli")
        .env("LC_ALL", "C")
        .args(args)
        .output()
        .map_err(|e| format!("Impossible de lancer nmcli : {e}"))?;
    if out.status.success() {
        Ok(String::from_utf8_lossy(&out.stdout).into_owned())
    } else {
        Err(translate(String::from_utf8_lossy(&out.stderr).trim()))
    }
}

fn translate(err: &str) -> String {
    let e = err.to_lowercase();
    if e.contains("secrets were required") || e.contains("no secrets") || e.contains("psk") {
        "Mot de passe incorrect ou manquant.".into()
    } else if e.contains("no network with ssid") {
        "Réseau introuvable, relance un scan.".into()
    } else if e.contains("not authorized") {
        "Action non autorisée par polkit.".into()
    } else if e.contains("timeout") || e.contains("timed out") {
        "Délai dépassé.".into()
    } else {
        err.trim_start_matches("Error: ").to_string()
    }
}

/// Découpe une ligne `nmcli -t` : champs séparés par ':', avec `\:` et `\\` échappés.
fn split_terse(line: &str) -> Vec<String> {
    let mut fields = vec![String::new()];
    let mut chars = line.chars();
    while let Some(c) = chars.next() {
        match c {
            '\\' => fields.last_mut().unwrap().extend(chars.next()),
            ':' => fields.push(String::new()),
            _ => fields.last_mut().unwrap().push(c),
        }
    }
    fields
}

fn wifi_iface() -> Result<Option<String>, String> {
    let out = nmcli(&["-t", "-f", "DEVICE,TYPE", "device"])?;
    Ok(out
        .lines()
        .map(split_terse)
        .find(|f| f.len() >= 2 && f[1] == "wifi")
        .map(|f| f[0].clone()))
}

/// SSID → UUID des profils Wi-Fi enregistrés.
fn profiles() -> Result<HashMap<String, String>, String> {
    let out = nmcli(&["-t", "-f", "UUID,TYPE", "connection", "show"])?;
    let mut map = HashMap::new();
    for f in out.lines().map(split_terse) {
        if f.len() < 2 || f[1] != "802-11-wireless" {
            continue;
        }
        let uuid = &f[0];
        if let Ok(ssid) = nmcli(&["-g", "802-11-wireless.ssid", "connection", "show", "uuid", uuid])
        {
            let ssid = split_terse(ssid.trim()).join(":");
            map.insert(ssid, uuid.clone());
        }
    }
    Ok(map)
}

pub fn scan(rescan: bool) -> Result<State, String> {
    let Some(iface) = wifi_iface()? else {
        return Ok(State::default());
    };
    let enabled = nmcli(&["-t", "-f", "WIFI", "radio"])?.trim() == "enabled";
    if !enabled {
        return Ok(State { iface: Some(iface), enabled, networks: Vec::new() });
    }

    let list = |rescan: &str| {
        nmcli(&[
            "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
            "device", "wifi", "list", "ifname", &iface, "--rescan", rescan,
        ])
    };
    // NetworkManager refuse un scan trop rapproché du précédent : on se rabat sur le cache.
    let out = if rescan { list("yes").or_else(|_| list("no"))? } else { list("no")? };

    let profiles = profiles()?;
    let mut by_ssid: HashMap<String, Network> = HashMap::new();
    for f in out.lines().map(split_terse) {
        if f.len() < 4 || f[1].is_empty() {
            continue; // SSID masqué
        }
        let net = Network {
            ssid: f[1].clone(),
            signal: f[2].parse().unwrap_or(0),
            security: if f[3] == "--" { String::new() } else { f[3].clone() },
            in_use: f[0].trim() == "*",
            profile: profiles.get(&f[1]).cloned(),
        };
        // Un SSID est souvent annoncé par plusieurs points d'accès : on garde le meilleur.
        match by_ssid.get_mut(&net.ssid) {
            Some(prev) => {
                let in_use = prev.in_use || net.in_use;
                if net.signal > prev.signal {
                    *prev = net;
                }
                prev.in_use = in_use;
            }
            None => {
                by_ssid.insert(net.ssid.clone(), net);
            }
        }
    }

    let mut networks: Vec<Network> = by_ssid.into_values().collect();
    networks.sort_by(|a, b| {
        (b.in_use, b.bars())
            .cmp(&(a.in_use, a.bars()))
            .then_with(|| a.ssid.to_lowercase().cmp(&b.ssid.to_lowercase()))
    });
    Ok(State { iface: Some(iface), enabled, networks })
}

pub fn connect(net: &Network, password: Option<&str>) -> Result<(), String> {
    if let Some(uuid) = &net.profile {
        return nmcli(&["-w", "30", "connection", "up", "uuid", uuid]).map(drop);
    }
    let mut args = vec!["-w", "30", "device", "wifi", "connect", net.ssid.as_str()];
    if let Some(password) = password {
        args.extend(["password", password]);
    }
    let result = nmcli(&args).map(drop);
    if result.is_err() {
        // nmcli laisse derrière lui un profil inutilisable (mauvais mot de passe…) :
        // on le retire pour que le prochain essai redemande le mot de passe.
        if let Some(uuid) = profiles().ok().and_then(|p| p.get(&net.ssid).cloned()) {
            let _ = nmcli(&["connection", "delete", "uuid", &uuid]);
        }
    }
    result
}

pub fn disconnect(iface: &str) -> Result<(), String> {
    nmcli(&["device", "disconnect", iface]).map(drop)
}

pub fn forget(uuid: &str) -> Result<(), String> {
    nmcli(&["connection", "delete", "uuid", uuid]).map(drop)
}

pub fn set_radio(on: bool) -> Result<(), String> {
    nmcli(&["radio", "wifi", if on { "on" } else { "off" }]).map(drop)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn terse_fields_are_unescaped() {
        assert_eq!(
            split_terse(r"*:caf\:e\\net:77:WPA2 WPA3"),
            vec!["*", r"caf:e\net", "77", "WPA2 WPA3"]
        );
        assert_eq!(split_terse(":open:40:"), vec!["", "open", "40", ""]);
    }

    #[test]
    fn errors_are_translated() {
        assert_eq!(
            translate("Error: Connection activation failed: (7) Secrets were required, but not provided."),
            "Mot de passe incorrect ou manquant."
        );
        assert_eq!(translate("Error: something else"), "something else");
    }
}
