# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# Demo Terraform na Azure (szkolenie)

Pracujesz w ograniczonej demo. Masz uprawnienia Contributor **tylko** na jednej,
już istniejącej grupie zasobów. Poświadczenia i nazwa RG są w zmiennych środowiskowych
(`ARM_*`, `TF_VAR_resource_group_name`, `TF_VAR_location`), więc nigdy ich nie wypisuj i nie
zapisuj do plików.

## Zasady

- Grupa zasobów **już istnieje**. Używaj `data "azurerm_resource_group" "main"`, nigdy `resource`.
- Wszystkie zasoby tworzysz w tej RG i w regionie z `var.location`. Nie wpisuj regionu na sztywno.
- Tagi bierz z RG: `tags = data.azurerm_resource_group.main.tags`.
- Nie zmieniaj `resource_provider_registrations = "none"` w `providers.tf`. Providery są zarejestrowane
  przez prowadzącego, a Twoja tożsamość nie ma do tego uprawnień.
- Dozwolone rozmiary VM: tylko `Standard_B1s` (1 vCPU). Limit vCPU na region dla całej subskrypcji to 10,
  więc **maksymalnie 1 VM na kursanta jednocześnie** — usuń poprzednią VM (`terraform destroy`), zanim stawiasz kolejną.
- Zakazane (polityka Azure zablokuje): Azure Firewall, Bastion, VPN/ExpressRoute Gateway, Application Gateway,
  NAT Gateway, AKS, Databricks, Synapse, Cosmos DB, Cognitive Services, Front Door/CDN. Uwaga: `plan` dla nich
  przechodzi, a odrzuca je dopiero `apply`. Inne regiony niż `var.location` też blokuje polityka.
- Nazwy storage account, Key Vault itp. muszą być globalnie unikalne. Dodaj losowy sufiks (`random_string`).
- Nie próbuj obchodzić uprawnień ani polityk. Przy `AuthorizationFailed` albo `RequestDisallowedByPolicy`
  zaproponuj tańsze lub mniejsze rozwiązanie albo powiedz użytkownikowi, że to blokada demo.
  `QuotaExceeded` zwykle oznacza, że VM już stoi (najpierw `destroy`). `AADSTS7000215` to wygasły sekret
  (ważny 7 dni), a nowy plik `.env` wydaje prowadzący.

## Sposób pracy

1. Zmień kod (`main.tf`, `variables.tf`, `outputs.tf`). Po każdej edycji hook uruchamia `fmt` i `validate`.
2. `terraform plan` (albo `/plan-review`, żeby dostać recenzję planu).
3. Pokaż użytkownikowi krótkie podsumowanie planu i poproś o zgodę.
4. `terraform apply` **bez** `-auto-approve`. Użytkownik zatwierdza go sam.
5. Zweryfikuj wynik (`terraform output`, `az resource list -g $TF_VAR_resource_group_name -o table`).

Odpowiadaj po polsku, zwięźle.

## Komendy

```bash
source ~/.tf-training/studentNN.env   # w każdej nowej sesji terminala (nie czytaj tego pliku)
terraform init
terraform fmt -check -recursive -diff && terraform validate   # to samo robi CI (tam: init -backend=false)
terraform plan
./scripts/login.sh                    # opcjonalnie: az login jako service principal (do `az resource list`)
```

Testów nie ma. Weryfikacją jest `fmt` + `validate` + `plan`.

## Architektura

- Płaski root module, bez podmodułów i bez zdalnego backendu (stan lokalny). Zasoby są podzielone na pliki
  tematyczne: `network.tf`, `security.tf` (`random_string.suffix`), `monitoring.tf` (action group; alert
  na usunięcie RG to zadanie dla kursantów), `main.tf` (`data` RG + output). Zmienne są w `variables.tf`, a `alert_email` w `monitoring.tf`.
- Pliki `*.disabled` (`vm.tf.disabled`, `storage.tf.disabled`) to gotowe, wyłączone przykłady ćwiczeń
  (VM nginx `Standard_B1s`, storage account). Terraform je ignoruje. Włączasz je przez usunięcie
  rozszerzenia `.disabled`. Pamiętaj o limicie 1 VM. `vm.tf` czyta klucz `~/.ssh/id_ed25519.pub` (musi istnieć)
  i ma własny VNet/NSG (port 80 otwarty). `storage.tf` bierze sufiks z `md5` ID grupy zasobów, a nie z `random_string`.
- Alert activity log (zadanie kursantów) ma `location = "global"`, więc jest jedynym wyjątkiem od zasady `var.location`.

## Automatyzacja w `.claude/`

- `settings.json`: allowlista read-only komend `terraform`/`az`. `apply`/`destroy` wymagają zgody (`ask`).
  Zablokowane są `az login/role/policy/provider`, `printenv`/`env` i odczyt `~/.tf-training/`.
- Hooki: `guard-terraform.sh` (PreToolUse) blokuje `apply`/`destroy` z flagą auto-approve. Dopasowuje tekst
  całego polecenia, więc daje fałszywe alarmy, gdy takie słowa są w treści heredoca. `tf-check.sh` (PostToolUse)
  robi `fmt` + `validate` po edycji `.tf` (wymaga `jq` i wcześniejszego `terraform init`).
- `/plan-review` uruchamia `terraform plan` i przekazuje wynik subagentowi `tf-reviewer` (tylko odczyt).
- CI: `ci.yaml` (fmt + validate na PR/push do `main`). `cd.yaml` uruchamiany ręcznie (plan, potem apply
  za zatwierdzeniem w środowisku `production`).
- `INSTRUKCJE.md` to instrukcja dla kursanta (setup, zasady, typowe błędy). Przy zmianie zasad demo aktualizuj
  ją razem z tym plikiem i z `.claude/agents/tf-reviewer.md` (ten dopuszcza więcej rozmiarów VM niż `Standard_B1s`
  i nie wymienia Front Door/CDN).
