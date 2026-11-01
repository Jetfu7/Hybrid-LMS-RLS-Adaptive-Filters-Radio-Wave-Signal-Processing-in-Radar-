# Hybrid LMS–RLS Adaptive Filters for Radar Signal Denoising

[![Paper](https://img.shields.io/badge/Paper-IEEE_Access_Format_(PDF)-blue.svg)](https://github.com/user-attachments/files/34237542/IEEE-access_Muhammad_Ariq_Praditya.pdf)
[![MATLAB](https://img.shields.io/badge/Language-MATLAB-orange.svg)](https://www.mathworks.com/)

MATLAB simulation of two hybrid adaptive filters, **Cascade LMS→RLS** and **Parallel Mixture**, for removing white and colored noise from LFM pulsed radar echoes.

> 📄 Full mathematical derivations and equations are available in the [paper (PDF)](https://github.com/user-attachments/files/34237542/IEEE-access_Muhammad_Ariq_Praditya.pdf).

---

## ⚡ Highlights

| | |
| :--- | :--- |
| **Problem** | Radar echoes are buried in noise. LMS is cheap but converges slowly and struggles with correlated noise; RLS converges fast but is computationally expensive. |
| **Solution** | Two hybrid architectures that combine LMS and RLS: a threshold-based **Cascade** and an adaptively weighted **Parallel Mixture**. |
| **Result** | Parallel Mixture gave the best result in every scenario: **+15.49 dB SNR gain** and **~91% lower MSE** in colored noise, **+10.72 dB SNR gain** and **~82% lower MSE** in white noise. |
| **Tools** | MATLAB, digital signal processing, adaptive filtering, radar signal modeling (LFM chirp, pulse compression, Doppler) |
| **Role** | First author: system modeling, algorithm design, simulation, and analysis. Supervised by Prof. Dr. Ir. Muhamad Asvial, M.Eng. |

---

## 📄 Paper Information

- **Title:** Design Simulation and Analysis of Hybrid LMS-RLS Adaptive Filters Radio Wave Signal Processing in Radar
- **Authors:** Muhammad Ariq Praditya, Muhamad Asvial (Member, IEEE)
- **Affiliation:** Department of Electrical Engineering, Faculty of Engineering, Universitas Indonesia, Depok 16424, Indonesia
- **Full text:** [Download PDF](https://github.com/user-attachments/files/34237542/IEEE-access_Muhammad_Ariq_Praditya.pdf)

---

## 📡 Radar Signal Model

The radar is modeled as a **monostatic pulsed radar**: the same antenna sends a pulse and listens for the echo.

- **Transmitted signal:** a Linear Frequency Modulation (LFM) pulse, also called a chirp, whose frequency rises linearly during the pulse. This lets the radar send a long, high-energy pulse while still getting fine range resolution.
- **Received echo:** a delayed and weakened copy of the transmitted chirp. The delay comes from the target's distance (30 km), and a small frequency shift (Doppler) comes from the target's motion (30 m/s).
- **Pulse compression:** a matched filter squeezes the long echo into a sharp peak at the target's position, which is how the radar detects the target.

**Noise scenarios**

- **White Gaussian noise:** random, uncorrelated noise spread evenly across all frequencies. Used as a baseline.
- **Colored noise:** correlated noise generated with a first-order autoregressive (AR(1)) model. It is closer to real clutter or jamming and is harder for adaptive filters to remove.

---

## ⚙️ Adaptive Filtering Methods

Every method uses a filter order of 32 and works as a noise canceller: it learns the noise pattern from a reference input and removes it from the noisy radar echo.

| Method | How it works | Strength | Weakness |
| :--- | :--- | :--- | :--- |
| **LMS** (baseline) | Adjusts its weights step by step to reduce the error | Simple and light to compute | Slow to converge, weak against colored noise |
| **RLS** (baseline) | Uses the full history of past data to update its weights | Fast convergence and good tracking | Much heavier to compute |
| **Cascade LMS→RLS** (proposed) | LMS runs on every sample. RLS is switched on only when the LMS error goes above a threshold (0.05) | Better accuracy than LMS while saving computation | Some noise artifacts remain because RLS is not always active |
| **Parallel Mixture** (proposed) | LMS and RLS run at the same time, and their outputs are blended using an adaptive weight α(n) | Best accuracy in every scenario | Runs both filters continuously |

**How the Parallel Mixture decides the blend:** at every sample, the system compares the errors of both filters. When RLS is making large errors, α(n) moves toward 1 and the output relies more on LMS. When RLS is doing well, α(n) moves toward 0 and the output relies more on RLS. This happens automatically, without knowing the noise type in advance.

**Performance metrics:** results are measured with **SNR** (Signal-to-Noise Ratio, higher is better) and **MSE** (Mean Squared Error, lower is better), both computed against the clean radar signal.

---

## 📊 Results

### White Gaussian Noise

| Method | Output SNR (dB) | SNR Gain (dB) | MSE |
| :--- | :---: | :---: | :---: |
| Before filtering (baseline) | −6.70 | — | 2.68723 |
| Standalone LMS | −0.38 | +6.32 | 1.01852 |
| Cascade LMS → RLS | 1.68 | +8.38 | 0.73961 |
| **Parallel Mixture (proposed)** | **4.02** | **+10.72** | **0.48895** |

### Colored Noise

| Method | Output SNR (dB) | SNR Gain (dB) | MSE |
| :--- | :---: | :---: | :---: |
| Before filtering (baseline) | −10.31 | — | 5.32817 |
| Standalone LMS | 0.07 | +10.38 | 1.07686 |
| Cascade LMS → RLS | 1.08 | +11.39 | 0.86476 |
| **Parallel Mixture (proposed)** | **5.18** | **+15.49** | **0.45637** |

### Key findings

1. **LMS** works reasonably in white noise but its output stays noisy and distorted in colored noise, because it cannot handle the correlation in the noise.
2. **Cascade LMS→RLS** improves on LMS in both scenarios by calling RLS only when needed, keeping computation lower than running RLS all the time.
3. **Parallel Mixture** gives the highest SNR and lowest MSE in both scenarios, with the clearest advantage in colored noise.
4. **Mixing weight behavior:** in white noise, α(n) often stays near 1, so LMS dominates. In colored noise, α(n) swings across the full 0 to 1 range, showing that the system leans on RLS more to handle correlated noise.
5. **Radar impact:** after pulse compression, the filtered signals show a much lower noise floor and a clear target peak at the correct range, with no timing distortion.

---

## 🖼️ Figures

### Radar signal validation

| Tx vs. Echo Envelope | Tx vs. Echo (Real Part, Zoomed) |
| :---: | :---: |
| ![Tx vs Echo Envelope](https://github.com/user-attachments/assets/50066349-113d-4d27-926c-aa1c7a4fcd9b) | ![Tx vs Echo Real Zoom](https://github.com/user-attachments/assets/04587c14-8f3c-4554-ba20-2153147def75) |

### Pulse compression and range profile

| Clean vs. Noisy Range Profile | Raw vs. Denoised Range Profile |
| :---: | :---: |
| ![Clean vs Noisy Range Profile](https://github.com/user-attachments/assets/191ee368-1217-4802-bac6-12feac972c7e) | ![Raw vs Denoised Range Profile](https://github.com/user-attachments/assets/9a6c9bf6-5662-44ae-9438-18cb3028611c) |

| Multi-Pulse Range Profile | Doppler Spectrum |
| :---: | :---: |
| ![Multi-Pulse Range Profile](https://github.com/user-attachments/assets/c0139516-366f-4a25-88ec-d308a74fc2f9) | ![Radar Doppler Spectrum](https://github.com/user-attachments/assets/3231add0-8003-470e-895a-e87662ad0c14) |

### Denoised waveforms

| LMS | Cascade LMS→RLS | Parallel Mixture |
| :---: | :---: | :---: |
| ![LMS Waveform](https://github.com/user-attachments/assets/9f7d77ec-f992-4d97-8180-a9143dc2d0cd) | ![Cascade Waveform](https://github.com/user-attachments/assets/707b14f5-fc95-4c2a-802d-82c25c1841ca) | ![Parallel Waveform](https://github.com/user-attachments/assets/0a941c79-22c8-4bea-970f-9c0aa0e9e433) |

### Convergence and mixing analysis

| SNR Comparison | MSE Comparison |
| :---: | :---: |
| ![SNR Comparison](https://github.com/user-attachments/assets/c1af9579-167f-4931-9977-2bc301cba8bd) | ![MSE Comparison](https://github.com/user-attachments/assets/f84922df-dfd1-437e-b5b5-7d26100e1e4e) |

| Running MSE | Mixing Weight α(n) |
| :---: | :---: |
| ![Running MSE](https://github.com/user-attachments/assets/72b73e3d-042b-49ed-a259-c9bca8774261) | ![Mixing Coefficient](https://github.com/user-attachments/assets/417687d0-25b8-47ce-82f3-26c8f6853c5f) |

---

## 🛠️ Simulation Parameters

| Category | Parameter | Value |
| :--- | :--- | :--- |
| Signal & sampling | Sampling frequency | 2 MHz |
| | Signal duration | 2.5 ms |
| Radar (LFM pulsed) | Chirp bandwidth | 200 kHz |
| | Pulse width | 1 ms |
| | Carrier frequency | 2.4 GHz |
| | Target range | 30 km |
| | Radial velocity | 30 m/s |
| Adaptive filter | Filter order | 32 |
| LMS | Step size | 0.001 |
| RLS | Forgetting factor | 0.995 |
| | Regularization | 1 |
| Cascade | Forgetting factor | 0.9995 |
| | Regularization | 100 |
| | Error threshold | 0.05 |
| Noise | White noise standard deviation | 1.5 |
| | Colored noise standard deviation | 0.5 |
| | AR(1) coefficient | 0.9 |

---

## 👤 Author

**Muhammad Ariq Praditya**
B.S. Electrical Engineering, Universitas Indonesia
Interests: radar signal processing, adaptive filters, digital signal processing
📧 muhammad.ariq11@ui.ac.id

Supervisor: **Prof. Dr. Ir. Muhamad Asvial, M.Eng.** (Member, IEEE), Department of Electrical Engineering, Universitas Indonesia
