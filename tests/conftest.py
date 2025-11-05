"""Pytest configuration and fixtures."""

import pytest
import torch


@pytest.fixture
def device():
    """Get the appropriate device for testing."""
    return torch.device('cuda' if torch.cuda.is_available() else 'cpu')


@pytest.fixture
def use_cuda():
    """Check if CUDA is available."""
    return torch.cuda.is_available()


@pytest.fixture
def sample_vocab_size():
    """Sample vocabulary size for testing."""
    return 10


@pytest.fixture
def sample_batch_size():
    """Sample batch size for testing."""
    return 4


@pytest.fixture
def sample_seq_len():
    """Sample sequence length for testing."""
    return 20


@pytest.fixture
def sample_embedding_dim():
    """Sample embedding dimension for testing."""
    return 32


@pytest.fixture
def sample_hidden_dim():
    """Sample hidden dimension for testing."""
    return 32


@pytest.fixture
def sample_data(sample_batch_size, sample_vocab_size, sample_seq_len):
    """Generate sample data for testing."""
    return torch.randint(0, sample_vocab_size, (sample_batch_size, sample_seq_len))
