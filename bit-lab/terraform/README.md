# BIT-Lab Terraform

Skeleton für Cloud-Migration des BIT-Labs nach AWS, Azure oder GCP.

## Status

⚠️ **Work in Progress**: Diese Terraform-Konfiguration ist ein Skeleton und muss für die jeweilige Cloud-Plattform angepasst werden.

## Struktur

- `main.tf`: Haupt-Konfiguration, Provider-Setup
- `variables.tf`: Alle konfigurierbaren Variablen
- `outputs.tf`: Output-Werte nach `terraform apply`
- `example.tf`: Beispiel-Konfigurationen für verschiedene Clouds

## Verwendung

### 1. Provider auswählen

Editiere `main.tf` und uncomment den gewünschten Provider:
- AWS
- Azure
- GCP

### 2. Credentials konfigurieren

```bash
# AWS
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."

# Azure
az login
export ARM_CLIENT_ID="..."
export ARM_CLIENT_SECRET="..."

# GCP
gcloud auth application-default login
export GOOGLE_APPLICATION_CREDENTIALS="path/to/credentials.json"
```

### 3. Terraform initialisieren

```bash
terraform init
```

### 4. Plan & Apply

```bash
terraform plan
terraform apply
```

## Anpassungen

1. **Module erstellen**: Erstelle Module in `modules/` für wiederverwendbare Komponenten
2. **Variablen anpassen**: Passe `variables.tf` an deine Anforderungen an
3. **Cloud-spezifische Konfiguration**: Siehe `example.tf` für Beispiele

## Weiterführende Ressourcen

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)







