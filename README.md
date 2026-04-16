<!----------/phaedrusflow/tds/README.md -------------------->
<!-- ----------TDS Professional Portfolio ----------------->
<!--------------------------------------------------------->

<h2>Matt A. Porter</h2>
<h3>Field Services Technician</h3>

![Repository Views](https://komarev.com/ghpvc/?username=phaedrusflow-tds)

<p align="center">
  <a href="https://tdstelecom.com">
    <img src="https://img.shields.io/badge/TDS_Telecom-Personal_Views_Only-005DAA?style=for-the-badge&logo=ethernet&logoColor=white"
      alt="Personal Views are my own and do not Reflect the views of TDS">
  </a>
  <br>
  <a href="https://www.fcc.gov/consumers/guides/types-broadband-connections">
    <img src="https://img.shields.io/badge/FCC_Broadband_Standards-blue?style=flat-square" alt="FCC Broadband Standards">
  </a>
  <a href="https://www.calix.com/platforms/axos.html">
    <img src="https://img.shields.io/badge/Calix_AXOS_Platform-blue?style=flat-square" alt="Calix AXOS Platform">
  </a>
  <a href="https://www.broadband-forum.org/resources">
    <img src="https://img.shields.io/badge/Broadband_Forum_Resources-green?style=flat-square" alt="Broadband Forum Resources">
  </a>
  <br>
  <a href="https://www.gnu.org/licenses/agpl-3.0">
    <img src="https://img.shields.io/badge/License-AGPL%20v3-blue.svg" alt="License: AGPL v3">
  </a>
  <a href="https://github.com/PhaedrusFlow">
    <img src="https://img.shields.io/badge/Views-My_Own%2C_Not_TDS-lightgrey?style=flat-square" alt="Views are my own, not TDS Telecom">
  </a>
</p>

---

<details>
<summary><strong>🧭 About Me</strong></summary>
<br>

<div align="center">
  <p>Matthew A. Porter<br>
  Former Intelligence Officer · Practical Technologist<br>
  TDS Field Services Technician · Founder, Amor Fati Labs</p>
</div>

### Publications

<p>
  <a href="https://orcid.org/0000-0002-0302-4812">
    <img src="https://img.shields.io/badge/ORCID-0000--0002--0302--4812-green?style=flat-square&logo=orcid" alt="ORCID">
  </a>
  <a href="https://www.researchgate.net/profile/Matt-Porter-7">
    <img src="https://img.shields.io/badge/ResearchGate-Open--Research-blue?style=flat-square&logo=researchgate" alt="ResearchGate">
  </a>
  <a href="https://zenodo.org/communities/qompassai">
    <img src="https://img.shields.io/badge/Zenodo-Publications-blue?style=flat-square&logo=zenodo" alt="Zenodo">
  </a>
</p>

### Developer Programs

[![NVIDIA Developer](https://img.shields.io/badge/NVIDIA-Developer_Program-76B900?style=for-the-badge&logo=nvidia&logoColor=white)](https://developer.nvidia.com/)
[![Meta Developer](https://img.shields.io/badge/Meta-Developer_Program-0668E1?style=for-the-badge&logo=meta&logoColor=white)](https://developers.facebook.com/)
[![HackerOne](https://img.shields.io/badge/-HackerOne-%23494649?style=for-the-badge&logo=hackerone&logoColor=white)](https://hackerone.com/phaedrusflow)
[![HuggingFace](https://img.shields.io/badge/HuggingFace-qompass-yellow?style=flat-square&logo=huggingface)](https://huggingface.co/qompass)
[![Epic Games Developer](https://img.shields.io/badge/Epic_Games-Developer_Program-313131?style=for-the-badge&logo=epic-games&logoColor=white)](https://dev.epicgames.com/)

### Professional Profiles

<p>
  <a href="https://www.linkedin.com/in/matt-a-porter-103535224/">
    <img src="https://img.shields.io/badge/LinkedIn-Matt--Porter-blue?style=flat-square&logo=linkedin" alt="Personal LinkedIn">
  </a>
  <a href="https://www.linkedin.com/company/95058568/">
    <img src="https://img.shields.io/badge/LinkedIn-Qompass--AI-blue?style=flat-square&logo=linkedin" alt="Startup LinkedIn">
  </a>
</p>

### Social Media

<p>
  <a href="https://twitter.com/PhaedrusFlow">
    <img src="https://img.shields.io/badge/Twitter-@PhaedrusFlow-blue?style=flat-square&logo=twitter" alt="X/Twitter">
  </a>
  <a href="https://www.instagram.com/phaedrusflow">
    <img src="https://img.shields.io/badge/Instagram-phaedrusflow-purple?style=flat-square&logo=instagram" alt="Instagram">
  </a>
  <a href="https://www.youtube.com/@qompassai">
    <img src="https://img.shields.io/badge/YouTube-QompassAI-red?style=flat-square&logo=youtube" alt="Qompass AI YouTube">
  </a>
</p>

</details>

---

<details id="fiber-physics">
<summary><strong>📡 Fiber Optic Physics</strong></summary>
<br>

### Q: How is fiber optic internet physically different from copper/coax?

**TLDR — light through glass beats electricity through metal.**

Traditional telco infrastructure (DSL, POTS) transmits electrical signals over copper twisted-pair, while coaxial cable uses a copper core with shielding. Fiber optic cable transmits data as pulses of light through ultra-pure glass or plastic strands. Single-mode fiber (SMF) — what TDS deploys for FTTH — uses a 9 µm core diameter to carry a single light mode with virtually no modal dispersion, enabling multi-gigabit speeds over distances exceeding 40 km without amplification.

**References**
- [TDS Fiber — What to Expect](https://tdstelecom.com/fiber)
- [ITU-T G.652 — Single-Mode Optical Fibre and Cable](https://www.itu.int/rec/T-REC-G.652)
- [IEEE 802.3 Ethernet Standards](https://standards.ieee.org/ieee/802.3)

---

### Total Internal Reflection — Why Light Stays in the Fiber

The critical angle $\theta_c$ at the core–cladding boundary is:

$$\theta_c = \arcsin\!\left(\frac{n_2}{n_1}\right)$$

| Symbol | Meaning | Typical value |
|--------|---------|---------------|
| $\theta_c$ | Critical angle | ~83.7° for SMF |
| $n_1$ | Refractive index, core | 1.468 (silica) |
| $n_2$ | Refractive index, cladding | 1.460 (silica cladding) |

When light strikes the core–cladding boundary at an angle **greater than** $\theta_c$, it reflects entirely back into the core with zero energy lost to the cladding — the fundamental mechanism that makes fiber work.

---

### Numerical Aperture

$$\text{NA} = \sqrt{n_1^2 - n_2^2}$$

- Single-mode fiber: NA ≈ 0.12 — tight beam, one propagation mode, minimal dispersion
- Multi-mode fiber: NA ≈ 0.20–0.50 — wider acceptance cone, shorter distances

---

### Optical Signal Attenuation Along a Fiber Span

Signal power at distance $L$ (km) from the source:

$$P(L) = P_0 \cdot 10^{\displaystyle\left(\frac{-\alpha L}{10}\right)}$$

Or equivalently in dB, where the received power in dBm is:

$$P_{\text{dBm}}(L) = P_{0,\text{dBm}} - \alpha L$$

| Symbol | Meaning | Typical value |
|--------|---------|---------------|
| $P_0$ | Launch power | +3 to +7 dBm (OLT transmitter) |
| $\alpha$ | Attenuation coefficient | 0.35 dB/km @ 1310 nm · 0.20 dB/km @ 1550 nm |
| $L$ | Fiber span length (km) | — |

**Example:** A 20 km run at 1310 nm loses $0.35 \times 20 = 7\text{ dB}$ in fiber alone, before any connector or splice losses.

---

### Optical Splitter Insertion Loss

PON networks use passive 1:N optical splitters. Each split divides the optical power equally — but the **dB loss does not divide equally**: it adds logarithmically.

**Ideal (theoretical) splitting loss for a 1:N splitter:**

$$IL_{\text{split}} = 10 \log_{10}(N) \text{ dB}$$

**Actual (excess loss included) insertion loss:**

$$IL_{\text{actual}} = 10 \log_{10}(N) + IL_{\text{excess}}$$

Where $IL_{\text{excess}}$ accounts for manufacturing imperfections (typically 0.1–0.5 dB for a PLC splitter).

| Split ratio $N$ | Ideal $IL$ | Typical actual $IL$ |
|-----------------|-----------|---------------------|
| 1:2  |  3.0 dB |  3.4 dB |
| 1:4  |  6.0 dB |  6.7 dB |
| 1:8  |  9.0 dB |  9.8 dB |
| 1:16 | 12.0 dB | 13.0 dB |
| 1:32 | 15.1 dB | 16.0 dB |
| 1:64 | 18.1 dB | 19.2 dB |

**Cascaded splitters** (e.g. a 1:4 feeding four 1:8s) add losses cumulatively:

$$IL_{\text{cascade}} = IL_1 + IL_2 = 10\log_{10}(N_1) + 10\log_{10}(N_2)$$

A 1:4 → 1:8 cascade gives an effective 1:32 split:
$$IL = 6.0 + 9.0 = 15.0 \text{ dB (ideal)}$$

---

### Total Optical Power Budget

The full end-to-end loss from OLT to ONT must stay within the **optical power budget** (OPB) of the system:

$$\text{OPB} = P_{\text{tx}} - P_{\text{rx,min}}$$

$$L_{\text{total}} = \underbrace{\alpha_f \cdot d}_{\text{fiber}} + \underbrace{\sum IL_{\text{split}}}_{\text{splitters}} + \underbrace{N_c \cdot \alpha_c}_{\text{connectors}} + \underbrace{N_s \cdot \alpha_s}_{\text{splices}} + \underbrace{M}_{\text{margin}}$$

| Term | Meaning | Typical value |
|------|---------|---------------|
| $\alpha_f$ | Fiber attenuation | 0.35 dB/km (1310 nm) |
| $d$ | Fiber distance (km) | — |
| $IL_{\text{split}}$ | Splitter insertion loss | See table above |
| $\alpha_c$ | Connector loss per pair | 0.3–0.5 dB |
| $\alpha_s$ | Splice loss per joint | 0.02–0.1 dB |
| $M$ | System margin (ageing, temp) | 1–3 dB |

**XGS-PON (ITU-T G.9807.1) class N2:** OPB = 29 dB — sufficient for a 1:32 split over ~20 km of feeder fiber.

**References**
- [ITU-T G.9807.1 — XGS-PON Standard](https://www.itu.int/rec/T-REC-G.9807.1)
- [Calix AXOS Platform](https://www.calix.com/platforms/axos.html)
- [Broadband Forum Resources](https://www.broadband-forum.org/resources)

---

### Shannon–Hartley — Maximum Theoretical Throughput

$$C = B \log_2\!\left(1 + \frac{S}{N}\right)$$

| Symbol | Meaning |
|--------|---------|
| $C$ | Channel capacity (bits/second) |
| $B$ | Bandwidth (Hz) |
| $S/N$ | Signal-to-noise ratio (linear) |

Fiber's near-zero noise floor and multi-THz optical bandwidth give it a theoretical capacity orders of magnitude above copper. A single SMF strand with dense wavelength-division multiplexing (DWDM) can carry **>100 Tbps** in laboratory conditions.

---

### Q: Why does fiber have symmetrical upload and download speeds?

Copper-based technologies (DSL, cable) are engineered asymmetrically because electrical signal transmission over legacy plant degrades upstream frequencies faster than downstream. Fiber carries light — upload and download travel on separate wavelengths (1310 nm upstream / 1490 nm downstream on GPON, or time-division multiplexed on XGS-PON) with identical physical characteristics in both directions, yielding true symmetrical throughput.

### Q: What is latency like on fiber vs. copper?

Light travels through silica fiber at approximately $2 \times 10^8$ m/s (roughly ⅔ the speed of light in vacuum). Propagation delay for a 100 km fiber span is ~0.5 ms one-way. DSL adds not only propagation delay but also interleaving delay (up to 20 ms on ADSL2+) and the latency of active amplification stages. Typical TDS Fiber round-trip latency to regional infrastructure is under 5 ms.

### Q: Do I need special equipment to use TDS Fiber?

TDS provides and installs an Optical Network Terminal (ONT) at your premises — a small device that converts the optical signal to Ethernet. You connect your router to the ONT's Ethernet port. No phone filters, DSL modems, or coax splitters needed.

**References**
- [What is an ONT? — TDS Support](https://tdstelecom.com/support)
- [Wi-Fi 6 Certified — Wi-Fi Alliance](https://www.wi-fi.org/discover-wi-fi/wi-fi-certified-6)
- [FCC Types of Broadband Connections](https://www.fcc.gov/consumers/guides/types-broadband-connections)

</details>

---

<details id="quantum">
<summary><strong>⚛️ Quantum Computing — Concepts &amp; Equations</strong></summary>
<br>

> **Try it live:** [Quirk — In-Browser Quantum Circuit Simulator](https://algassert.com/quirk) | [IBM Quantum Lab](https://quantum.ibm.com)

Quantum computing represents a fundamental shift from classical bit-based computation. Below are the core mathematical foundations, with interactive resources linked throughout.

---

### The Qubit — Superposition

A classical bit is always 0 or 1. A **qubit** exists in a superposition of both simultaneously:

$$|\psi\rangle = \alpha|0\rangle + \beta|1\rangle$$

Where $\alpha, \beta \in \mathbb{C}$ are probability amplitudes satisfying the **normalization constraint**:

$$|\alpha|^2 + |\beta|^2 = 1$$

$|\alpha|^2$ is the probability of measuring $|0\rangle$; $|\beta|^2$ is the probability of measuring $|1\rangle$. Measurement **collapses** the superposition irreversibly.

> **Interactive:** Build a single-qubit superposition in [Quirk](https://algassert.com/quirk) by dragging an **H** gate onto a qubit wire and observing the probability display.

---

### Bloch Sphere Representation

Any pure qubit state can be written in spherical coordinates on the Bloch sphere:

$$|\psi\rangle = \cos\!\frac{\theta}{2}|0\rangle + e^{i\phi}\sin\!\frac{\theta}{2}|1\rangle$$

| Parameter | Meaning |
|-----------|---------|
| $\theta \in [0, \pi]$ | Polar angle — mix of $\|0\rangle$ and $\|1\rangle$ |
| $\phi \in [0, 2\pi)$ | Azimuthal angle — relative phase |

The north pole ($\theta=0$) is $|0\rangle$; the south pole ($\theta=\pi$) is $|1\rangle$; the equator is maximum superposition.

---

### Quantum Gates — Unitary Transformations

All quantum gates are **unitary matrices** $U$ satisfying $U^\dagger U = I$.

**Pauli-X (bit flip / quantum NOT):**

$$X = \begin{pmatrix} 0 & 1 \\ 1 & 0 \end{pmatrix}$$

**Hadamard gate** — creates equal superposition from a basis state:

$$H = \frac{1}{\sqrt{2}}\begin{pmatrix} 1 & 1 \\ 1 & -1 \end{pmatrix}$$

$$H|0\rangle = \frac{|0\rangle + |1\rangle}{\sqrt{2}} = |{+}\rangle \qquad H|1\rangle = \frac{|0\rangle - |1\rangle}{\sqrt{2}} = |{-}\rangle$$

**Phase gate** $S$ and **T gate:**

$$S = \begin{pmatrix} 1 & 0 \\ 0 & i \end{pmatrix} \qquad T = \begin{pmatrix} 1 & 0 \\ 0 & e^{i\pi/4} \end{pmatrix}$$

**CNOT (controlled-NOT)** — the fundamental two-qubit entangling gate:

$$\text{CNOT} = \begin{pmatrix} 1 & 0 & 0 & 0 \\ 0 & 1 & 0 & 0 \\ 0 & 0 & 0 & 1 \\ 0 & 0 & 1 & 0 \end{pmatrix}$$

> **Interactive:** In [Quirk](https://algassert.com/quirk), place an H gate on qubit 1 and a CNOT with qubit 1 as control and qubit 2 as target. The probability display will show a 50/50 Bell state — the qubits are now **entangled**.

---

### Entanglement — Bell States

Applying $H$ then CNOT to $|00\rangle$ produces the first Bell state, a **maximally entangled** two-qubit state:

$$|\Phi^+\rangle = \frac{|00\rangle + |11\rangle}{\sqrt{2}}$$

The four Bell states form an orthonormal basis for two-qubit systems:

$$|\Phi^\pm\rangle = \frac{|00\rangle \pm |11\rangle}{\sqrt{2}} \qquad |\Psi^\pm\rangle = \frac{|01\rangle \pm |10\rangle}{\sqrt{2}}$$

Once entangled, measuring one qubit **instantly** determines the state of the other — regardless of physical separation. This is not faster-than-light signalling; no classical information is transmitted.

---

### Quantum Interference & the Deutsch Algorithm

Quantum algorithms exploit **constructive interference** (amplifying correct answers) and **destructive interference** (cancelling wrong answers).

The Deutsch oracle $U_f$ encodes a function $f:\{0,1\}\to\{0,1\}$ as:

$$U_f|x\rangle|y\rangle = |x\rangle|y \oplus f(x)\rangle$$

In a single query, the Deutsch algorithm determines whether $f$ is **constant** ($f(0)=f(1)$) or **balanced** ($f(0)\neq f(1)$) — something that requires 2 queries classically.

---

### Quantum Complexity — Grover's Search

For an unsorted database of $N$ items, classical search requires $O(N)$ queries. Grover's algorithm finds the target in:

$$O\!\left(\sqrt{N}\right) \text{ queries}$$

The optimal number of Grover iterations before measuring is:

$$k = \left\lfloor \frac{\pi}{4}\sqrt{N} \right\rfloor$$

For $N = 2^n$ (an $n$-qubit register), this gives a **quadratic speedup** — e.g. searching $2^{64}$ entries in ~$2^{32}$ steps instead of $2^{64}$.

---

### Quantum Fourier Transform (QFT)

The QFT is the quantum analogue of the discrete Fourier transform:

$$|\tilde{x}\rangle = \text{QFT}|x\rangle = \frac{1}{\sqrt{N}}\sum_{k=0}^{N-1} e^{2\pi i xk/N}|k\rangle$$

It is the core subroutine in **Shor's algorithm** (integer factoring in polynomial time) and **quantum phase estimation**. Classically, the FFT runs in $O(N \log N)$; the QFT runs in $O(n^2)$ gates for an $n$-qubit register — an exponential improvement.

---

### Quantum Decoherence & Fidelity

Real qubits lose their quantum state through interaction with the environment — **decoherence**. The state fidelity between the ideal state $|\psi\rangle$ and the actual (possibly mixed) state $\rho$ is:

$$F = \langle\psi|\rho|\psi\rangle$$

$F = 1$ is a perfect qubit; $F = 0.5$ is completely mixed (classical). Modern superconducting qubits achieve gate fidelities of 99.5–99.9% per two-qubit gate. Error correction requires fidelity above the **fault-tolerance threshold** (~99.0–99.9% depending on the code).

---

### Quantum Error Correction — The 3-Qubit Bit-Flip Code

To protect one logical qubit against a single bit-flip error, encode it across 3 physical qubits:

$$|0\rangle_L = |000\rangle \qquad |1\rangle_L = |111\rangle$$

Measure the **stabilizers** $Z_1Z_2$ and $Z_2Z_3$ (parity checks) without collapsing the logical state. A single-qubit error on any one of the three is detectable and correctable.

The more powerful **Shor code** uses 9 physical qubits per logical qubit and corrects arbitrary single-qubit errors ($X$, $Z$, and $Y$).

---

### Quantum Applications in Telecom

Quantum computing intersects with telecommunications in several active research areas:

| Application | Mechanism | Status |
|---|---|---|
| **Post-quantum cryptography** | Lattice-based / hash-based algorithms resistant to Shor's algorithm | Standardized by NIST 2024 |
| **Quantum key distribution (QKD)** | BB84 protocol — eavesdropping disturbs the quantum state, making it detectable | Commercial deployments exist |
| **Quantum network routing** | Entanglement-based channels for provably secure links | Research / early trials |
| **ML/optimization (QAOA)** | Quantum Approximate Optimization Algorithm for network resource allocation | Near-term / NISQ era |

**References**
- [IBM Quantum — Learn & Simulate](https://quantum.ibm.com)
- [Quirk — Interactive Quantum Circuit Simulator](https://algassert.com/quirk)
- [Introduction to Quantum Computing — LinkedIn Learning Certificate](./certs/CertificateOfCompletion_Introduction%20to%20Quantum%20Computing.pdf)
- [NIST Post-Quantum Cryptography Standards](https://csrc.nist.gov/projects/post-quantum-cryptography)
- [Qiskit Open-Source SDK](https://www.ibm.com/quantum/qiskit)

</details>

---

<details id="certs">
<summary><strong>📜 Certifications &amp; Credentials</strong></summary>
<br>

Full certificate index: [certs/README.md](./certs/README.md)

Selected credentials:

| Certificate | Provider |
|---|---|
| [Introduction to Quantum Computing](./certs/CertificateOfCompletion_Introduction%20to%20Quantum%20Computing.pdf) | LinkedIn Learning |
| [CompTIA Security+ SY0-701 Prep](./certs/CertificateOfCompletion_CompTIA%20Security%20SY0701%20Cert%20Prep.pdf) | LinkedIn Learning |
| [AI in RAN — Radio Access Network](./certs/CertificateOfCompletion_AI%20in%20RAN%20Radio%20Access%20Network%20Transforming%20Mobile%20Networks.pdf) | LinkedIn Learning |
| [Understanding Copper & Fiber Optic Systems](./certs/CertificateOfCompletion_Understanding%20Copper%20and%20Fiber%20Optic%20Communication%20Systems.pdf) | LinkedIn Learning |
| [Introduction to Telecom Standards, Networks & Innovations](./certs/CertificateOfCompletion_Introduction%20to%20Telecommunications%20Standards%20Networks%20and%20Innovations.pdf) | LinkedIn Learning |
| [Linux System Engineer: Networking & SSH](./certs/CertificateOfCompletion_Linux%20System%20Engineer%20Networking%20and%20SSH.pdf) | LinkedIn Learning |
| [ArcGIS Python Scripting](./certs/CertificateOfCompletion_Python%20Scripting%20Using%20the%20ArcGIS%20API%20for%20Python.pdf) | LinkedIn Learning |
| [InfraWorks & ArcGIS AEC Collaboration](./certs/CertificateOfCompletion_InfraWorks%20and%20ArcGIS%20AEC%20Collaboration.pdf) | LinkedIn Learning |
| [GitHub Actions](./certs/CertificateOfCompletion_Practical%20GitHub%20Actions.pdf) | LinkedIn Learning |
| [Project Management Foundations](./certs/CertificateOfCompletion_Project%20Management%20Foundations.pdf) | LinkedIn Learning |

</details>

---

> *Views expressed here are my own and do not represent TDS Telecom.*
