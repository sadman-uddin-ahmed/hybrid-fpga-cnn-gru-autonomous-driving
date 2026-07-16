# Temporal Model Comparison

This document summarises the temporal-model comparison used to select CNN-GRU for the hybrid FPGA-CNN-GRU perception pipeline.

The temporal modelling workflow extends the single-frame CNN perception baseline into a four-frame feature-sequence system. Each image frame is passed through the CNN feature extractor, producing an 8,192-value feature vector. A full temporal sample therefore contains four CNN feature vectors.

```text
4 frames × 8,192 features = 32,768 feature values
```

## Temporal input representation

| Item | Value |
|---|---:|
| Sequence length | 4 frames |
| Feature size per frame | 8,192 |
| Temporal feature shape | `[batch size, 4, 8192]` |
| Output classes | 2 |
| Class 0 | No car |
| Class 1 | Car present |

## Models evaluated

Three recurrent temporal models were evaluated under the same feature-sequence representation.

| Model | Recurrent block | Purpose |
|---|---|---|
| CNN-RNN | Basic RNN | Simple temporal baseline |
| CNN-LSTM | Long Short-Term Memory | Higher-capacity gated temporal modelling |
| CNN-GRU | Gated Recurrent Unit | Lightweight gated temporal modelling |

All three models used the same saved CNN feature sequences, the same sequence length, the same class labels, and the same binary classification target. This made the comparison controlled and fair.

## Training configuration

| Setting | Value |
|---|---:|
| Input feature size | 8,192 |
| Sequence length | 4 |
| Hidden size | 128 |
| Number of recurrent layers | 1 |
| Output classes | 2 |
| Dropout rate | 0.3 |
| Epochs | 10 |
| Batch size | 32 |
| Optimizer | Adam |
| Learning rate | 0.001 |
| Loss function | Weighted cross-entropy loss |

Weighted cross-entropy loss was used because the dataset was imbalanced, with more car-present samples than no-car samples.

| Class | Training samples | Class weight |
|---|---:|---:|
| No car | 545 | 5.4872 |
| Car present | 5,436 | 0.5501 |

The higher weight for the no-car class reduced the risk of the model becoming biased toward the majority car-present class.

## Model complexity

| Model | Trainable parameters |
|---|---:|
| CNN-RNN | 1,065,474 |
| CNN-GRU | 3,195,906 |
| CNN-LSTM | 4,261,122 |

CNN-RNN was the smallest model because it used a basic recurrent structure. CNN-LSTM was the largest model because it used multiple gates and a memory cell. CNN-GRU used fewer parameters than CNN-LSTM while still retaining gated temporal behaviour.

## Test-set performance

| Model | Test accuracy | Precision | Recall | F1-score |
|---|---:|---:|---:|---:|
| CNN-RNN | 98.40% | 98.83% | 99.41% | 99.12% |
| CNN-LSTM | 99.07% | 99.41% | 99.56% | 99.49% |
| CNN-GRU | 99.07% | 99.13% | 99.85% | 99.49% |

CNN-LSTM and CNN-GRU achieved the highest test accuracy and F1-score. CNN-GRU achieved the highest recall, which is important for car-presence detection because a false negative means the model failed to detect a car-present case.

## Confusion-matrix comparison

| Model | True positive | True negative | False positive | False negative |
|---|---:|---:|---:|---:|
| CNN-RNN | 677 | 61 | 8 | 4 |
| CNN-LSTM | 678 | 65 | 4 | 3 |
| CNN-GRU | 680 | 63 | 6 | 1 |

CNN-GRU produced the lowest false-negative count, with only one missed car-present sequence. This made it the strongest model from a safety-relevant recall perspective.

## Training-time comparison

| Model | Approximate average epoch time |
|---|---:|
| CNN-RNN | 2.90 s |
| CNN-GRU | 5.45 s |
| CNN-LSTM | 11.39 s |

CNN-RNN trained the fastest because it had the simplest recurrent structure. CNN-LSTM required the longest training time because it had the highest parameter count and the most complex recurrent operations. CNN-GRU required more time than CNN-RNN but much less than CNN-LSTM, supporting its use as a balanced temporal model.

## Comparison against the CNN baseline

The temporal models were also compared against the original single-frame CNN baseline.

| Model | Input type | Test accuracy | F1-score | Main purpose |
|---|---|---:|---:|---|
| CNN baseline | Single image | 98.25% | Not reported here | Spatial baseline |
| CNN-RNN | Four-frame CNN feature sequence | 98.40% | 99.12% | Simple temporal baseline |
| CNN-LSTM | Four-frame CNN feature sequence | 99.07% | 99.49% | Gated temporal modelling |
| CNN-GRU | Four-frame CNN feature sequence | 99.07% | 99.49% | Lightweight gated temporal modelling |

The comparison shows that temporal modelling improved the classification framework beyond the single-frame CNN baseline. CNN-RNN gave a small improvement, while CNN-LSTM and CNN-GRU produced the strongest classification results.

## Why CNN-GRU was selected

CNN-GRU was selected as the temporal model for hybrid validation because it provided the strongest balance between classification performance, recall, false-negative reduction, and model complexity.

The key reasons were:

- CNN-GRU matched CNN-LSTM test accuracy at 99.07%.
- CNN-GRU matched CNN-LSTM F1-score at 99.49%.
- CNN-GRU achieved the highest recall at 99.85%.
- CNN-GRU produced the lowest false-negative count, with only one missed car-present sequence.
- CNN-GRU used fewer trainable parameters than CNN-LSTM.
- CNN-GRU required less average training time than CNN-LSTM.
- CNN-GRU was more suitable than CNN-LSTM for a hardware-aware or hybrid deployment path because of its lower model complexity.

## Interpretation

CNN-RNN provided a useful temporal baseline and had the lowest parameter count, but its classification performance was weaker than the gated models.

CNN-LSTM achieved the highest precision and matched the highest test accuracy, but it required the largest parameter count and the longest training time. This makes it less attractive for a resource-constrained hardware-aware extension.

CNN-GRU achieved the same test accuracy and F1-score as CNN-LSTM while using fewer parameters and producing the lowest false-negative count. This made CNN-GRU the most practical temporal model for the hybrid FPGA-CNN-GRU architecture.

## Scope note

The CNN-GRU model is not implemented directly in FPGA fabric in this repository. The public implementation validates a hybrid architecture where the FPGA-side design performs W8A8 CNN feature extraction and temporal feature buffering, while CNN-GRU inference is performed on the host side.

This keeps the FPGA implementation focused on the computationally intensive spatial CNN feature-extraction path while preserving the validated temporal classification capability of the CNN-GRU model.
