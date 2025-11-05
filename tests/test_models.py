"""Tests for Sizzler models."""

import pytest
import torch

from sizzler.models.generator import Generator
from sizzler.models.discriminator import Discriminator
from sizzler.models.target_lstm import TargetLSTM
from sizzler.models.rollout import Rollout


class TestGenerator:
    """Tests for Generator model."""

    def test_generator_initialization(self, sample_vocab_size, sample_embedding_dim,
                                       sample_hidden_dim, use_cuda):
        """Test Generator initialization."""
        gen = Generator(sample_vocab_size, sample_embedding_dim,
                        sample_hidden_dim, use_cuda)
        assert gen is not None
        assert gen.hidden_dim == sample_hidden_dim

    def test_generator_forward(self, sample_vocab_size, sample_embedding_dim,
                               sample_hidden_dim, sample_data, use_cuda):
        """Test Generator forward pass."""
        gen = Generator(sample_vocab_size, sample_embedding_dim,
                        sample_hidden_dim, use_cuda)
        output = gen(sample_data)
        expected_size = sample_data.size(0) * sample_data.size(1)
        assert output.size(0) == expected_size
        assert output.size(1) == sample_vocab_size

    def test_generator_sample(self, sample_vocab_size, sample_embedding_dim,
                              sample_hidden_dim, sample_batch_size,
                              sample_seq_len, use_cuda):
        """Test Generator sampling."""
        gen = Generator(sample_vocab_size, sample_embedding_dim,
                        sample_hidden_dim, use_cuda)
        samples = gen.sample(sample_batch_size, sample_seq_len)
        assert samples.shape == (sample_batch_size, sample_seq_len)
        assert torch.all(samples >= 0)
        assert torch.all(samples < sample_vocab_size)


class TestDiscriminator:
    """Tests for Discriminator model."""

    def test_discriminator_initialization(self, sample_vocab_size, sample_embedding_dim):
        """Test Discriminator initialization."""
        num_classes = 2
        filter_sizes = [2, 3, 4, 5]
        num_filters = [100, 100, 100, 100]
        dropout_prob = 0.5
        disc = Discriminator(num_classes, sample_vocab_size, sample_embedding_dim,
                             filter_sizes, num_filters, dropout_prob)
        assert disc is not None

    def test_discriminator_forward(self, sample_vocab_size, sample_embedding_dim,
                                    sample_data):
        """Test Discriminator forward pass."""
        num_classes = 2
        filter_sizes = [2, 3, 4, 5]
        num_filters = [100, 100, 100, 100]
        dropout_prob = 0.5
        disc = Discriminator(num_classes, sample_vocab_size, sample_embedding_dim,
                             filter_sizes, num_filters, dropout_prob)
        output = disc(sample_data)
        assert output.size(0) == sample_data.size(0)
        assert output.size(1) == num_classes


class TestTargetLSTM:
    """Tests for TargetLSTM model."""

    def test_target_lstm_initialization(self, sample_vocab_size, sample_embedding_dim,
                                         sample_hidden_dim, use_cuda):
        """Test TargetLSTM initialization."""
        target_lstm = TargetLSTM(sample_vocab_size, sample_embedding_dim,
                                  sample_hidden_dim, use_cuda)
        assert target_lstm is not None
        assert target_lstm.hidden_dim == sample_hidden_dim

    def test_target_lstm_sample(self, sample_vocab_size, sample_embedding_dim,
                                sample_hidden_dim, sample_batch_size,
                                sample_seq_len, use_cuda):
        """Test TargetLSTM sampling."""
        target_lstm = TargetLSTM(sample_vocab_size, sample_embedding_dim,
                                  sample_hidden_dim, use_cuda)
        samples = target_lstm.sample(sample_batch_size, sample_seq_len)
        assert samples.shape == (sample_batch_size, sample_seq_len)
        assert torch.all(samples >= 0)
        assert torch.all(samples < sample_vocab_size)


class TestRollout:
    """Tests for Rollout policy."""

    def test_rollout_initialization(self, sample_vocab_size, sample_embedding_dim,
                                     sample_hidden_dim, use_cuda):
        """Test Rollout initialization."""
        gen = Generator(sample_vocab_size, sample_embedding_dim,
                        sample_hidden_dim, use_cuda)
        rollout = Rollout(gen, update_rate=0.8)
        assert rollout is not None
        assert rollout.update_rate == 0.8
        assert rollout.ori_model is gen
