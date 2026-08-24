# Workplace Automation Platform

PowerShell-based automation tools designed to simplify recurring Windows Workplace support operations, standardize troubleshooting procedures and reduce manual intervention.

## About

The **Workplace Automation Platform (WAP)** is an automation initiative focused on improving repetitive technical support processes through PowerShell and enterprise deployment technologies.

These tools were originally developed as part of an **enterprise Workplace Automation Platform** and later refactored to operate independently from the original corporate environment.

The current repository contains the first three automation tools developed for the platform.

The project was designed with enterprise environments in mind, including centralized deployment through **Microsoft Configuration Manager (SCCM)** and structured execution logging.

---

## Objectives

The platform was created to address recurring support scenarios that traditionally require manual intervention.

### Main goals

* Reduce repetitive technical support tasks
* Decrease troubleshooting time
* Standardize support procedures
* Improve operational scalability
* Increase Workplace team productivity
* Provide consistent diagnostic and repair routines
* Enable centralized deployment through SCCM
* Collect execution data for operational analysis

---

## Available Tools

### 1. Teams Repair

Automates common Microsoft Teams troubleshooting procedures.

The script performs:

* Teams process termination
* Microsoft Edge WebView process termination
* Teams cache cleanup
* Multiple cache removal attempts with retry logic
* Teams application restart
* Execution logging
* Error categorization
* User and workstation identification
* Optional Active Directory department lookup

**Status:** Production

---

### 2. Windows Quick Repair

Performs a set of fast Windows troubleshooting and maintenance procedures commonly used during daily Workplace support.

The automation includes:

* DNS cache flush
* Winsock reset
* TCP/IP reset
* User TEMP cleanup
* Windows TEMP cleanup
* Teams cache cleanup
* Windows Explorer restart
* System information collection
* Execution logging
* Error handling and categorization

**Status:** Production

---

### 3. Windows Advanced Repair

Provides a more comprehensive Windows troubleshooting and repair routine for recurring operating system issues.

The automation includes procedures such as:

* System File Checker (SFC)
* DISM health restoration
* CHKDSK scan
* Disk optimization
* Windows Update service reset
* Windows Update cache cleanup
* System diagnostics
* Network information collection
* Disk space monitoring
* System uptime collection
* Execution logging
* Error categorization
* User and workstation identification

**Status:** Production

---

## Architecture

The tools follow a simple automation and telemetry workflow:

```text
┌──────────────────────┐
│    PowerShell Tool   │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  Troubleshooting &   │
│      Repair Logic    │
└──────────┬───────────┘
           │
           ├──────────────► Local Logs
           │
           ▼
┌──────────────────────┐
│ Execution Telemetry  │
│      JSON / CSV      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│      Power BI        │
│   Operational Data   │
└──────────────────────┘
```

The architecture was designed to allow the automation layer to execute independently while generating structured information that can later be consumed by reporting and analytics solutions.

---

## Enterprise Deployment

The scripts were designed with **Microsoft Configuration Manager (SCCM)** deployment in mind.

This allows the tools to be distributed centrally and executed across managed Windows endpoints without requiring manual installation on each machine.

Example deployment concept:

```text
SCCM
 │
 ├── Teams Repair
 │
 ├── Windows Quick Repair
 │
 └── Windows Advanced Repair
          │
          ▼
     Windows Endpoint
          │
          ├── Repair
          ├── Logging
          └── Telemetry
```

This approach transforms individual PowerShell scripts into reusable support capabilities within a managed Workplace environment.

---

## Logging & Telemetry

Each automation generates execution information to support troubleshooting, auditing and operational analysis.

Collected information may include:

* Execution timestamp
* Logged-in user
* Computer name
* IPv4 address
* Department
* Available disk space
* System uptime
* Execution status
* Error message
* Error category
* Execution duration
* Retry attempts

The telemetry layer was designed to support the future WAP dashboard.

### Planned data flow

```text
PowerShell
     │
     ▼
   JSON
     │
     ▼
   CSV
     │
     ▼
 Power BI
```

This allows technical automation to generate measurable operational data instead of simply executing a repair procedure.

---

## Technologies

* PowerShell
* Windows Enterprise
* Microsoft Configuration Manager (SCCM)
* Active Directory
* Power BI
* JSON
* CSV
* Git
* GitHub

---

## Project Roadmap

### Completed

* [x] Teams Repair
* [x] Windows Quick Repair
* [x] Windows Advanced Repair
* [x] PowerShell-based automation
* [x] Error handling
* [x] Execution logging
* [x] Structured telemetry
* [x] SCCM-oriented execution

### Planned

* [ ] SAP List Repair
* [ ] DBeaver auto-config with SSO
* [ ] Docker package installer (WSL+UBUNTU+DOCKER)
* [ ] Reusable configuration layer
* [ ] Expanded documentation
* [ ] WAP operational dashboard
* [ ] Additional Workplace automation tools
* [ ] Modular architecture
* [ ] Broader cross-environment compatibility

---

## Production & Public Version

The original WAP tools were created to solve real recurring problems within an enterprise Workplace operation.

The public version of this repository focuses on demonstrating the technical concepts, automation architecture and engineering practices behind the solution without exposing proprietary infrastructure or corporate information.

The project is continuously evolving from a production-oriented internal solution toward a more modular and reusable automation toolkit.

---

## Security & Privacy

This repository does not contain:

* Corporate credentials
* Internal passwords
* Private keys
* Production secrets
* Internal server addresses
* Confidential infrastructure information
* Proprietary corporate data

Environment-specific configuration should be adapted before deploying these scripts in another organization.

---

## Author

**Vinicius Correia**

Analyst focused on **Workplace, IT Automation, PowerShell and Windows Infrastructure**.

The WAP project represents an ongoing effort to transform repetitive Workplace support procedures into standardized, scalable and measurable automation solutions.
