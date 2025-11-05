"""Tests for training utilities."""

import pytest
import torch
import tempfile
from pathlib import Path

from sizzler.training.data_iter import GenDataIter, DisDataIter
from sizzler.training.loss import PGLoss


class TestGenDataIter:
    """Tests for GenDataIter."""

    def test_gen_data_iter_initialization(self, tmp_path):
        """Test GenDataIter initialization."""
        # Create a temporary data file
        data_file = tmp_path / "test_data.txt"
        with open(data_file, 'w') as f:
            f.write("1 2 3 4 5\n")
            f.write("6 7 8 9 10\n")

        data_iter = GenDataIter(str(data_file), batch_size=2)
        assert data_iter.batch_size == 2
        assert data_iter.data_num == 2

    def test_gen_data_iter_iteration(self, tmp_path):
        """Test GenDataIter iteration."""
        # Create a temporary data file
        data_file = tmp_path / "test_data.txt"
        with open(data_file, 'w') as f:
            f.write("1 2 3 4 5\n")
            f.write("6 7 8 9 10\n")

        data_iter = GenDataIter(str(data_file), batch_size=1)
        data, target = next(data_iter)
        assert data.shape[0] == 1
        assert target.shape[0] == 1


class TestDisDataIter:
    """Tests for DisDataIter."""

    def test_dis_data_iter_initialization(self, tmp_path):
        """Test DisDataIter initialization."""
        # Create temporary data files
        real_file = tmp_path / "real_data.txt"
        fake_file = tmp_path / "fake_data.txt"

        with open(real_file, 'w') as f:
            f.write("1 2 3 4 5\n")
            f.write("6 7 8 9 10\n")

        with open(fake_file, 'w') as f:
            f.write("11 12 13 14 15\n")

        data_iter = DisDataIter(str(real_file), str(fake_file), batch_size=2)
        assert data_iter.batch_size == 2
        assert data_iter.data_num == 3  # 2 real + 1 fake


class TestPGLoss:
    """Tests for PGLoss."""

    def test_pg_loss_initialization(self):
        """Test PGLoss initialization."""
        pg_loss = PGLoss()
        assert pg_loss is not None

    def test_pg_loss_forward(self):
        """Test PGLoss forward pass."""
        pg_loss = PGLoss()
        batch_size = 4
        seq_len = 10
        vocab_size = 10

        pred = torch.randn(batch_size * seq_len, vocab_size)
        target = torch.randint(0, vocab_size, (batch_size, seq_len))
        reward = torch.randn(batch_size, seq_len)

        loss = pg_loss(pred, target, reward)
        assert loss.dim() == 0  # Scalar loss
        assert isinstance(loss.item(), float)
