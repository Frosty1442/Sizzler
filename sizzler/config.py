"""Configuration management for Sizzler."""

import os
from pathlib import Path


# Default paths - use environment variables or fallback to defaults
DEFAULT_DATA_PATH = Path(os.getenv('SIZZLER_DATA_PATH', Path.cwd() / 'data'))
DEFAULT_OUTPUT_PATH = Path(os.getenv('SIZZLER_OUTPUT_PATH', Path.cwd() / 'output'))

# Ensure directories exist
DEFAULT_DATA_PATH.mkdir(parents=True, exist_ok=True)
DEFAULT_OUTPUT_PATH.mkdir(parents=True, exist_ok=True)


class Config:
    """Configuration class for Sizzler training parameters."""

    def __init__(self):
        # Paths
        self.data_path = DEFAULT_DATA_PATH
        self.output_path = DEFAULT_OUTPUT_PATH

        # Training hyperparameters
        self.rounds = 150
        self.g_pretrain_steps = 120
        self.d_pretrain_steps = 50
        self.g_steps = 1
        self.d_steps = 3
        self.gk_epochs = 1
        self.dk_epochs = 3

        # Model hyperparameters
        self.vocab_size = 10
        self.batch_size = 32
        self.n_samples = 6400
        self.seq_len = 20
        self.emb_dim = 32
        self.hidden_dim = 32

        # Optimization
        self.gen_lr = 1e-3
        self.dis_lr = 1e-3
        self.update_rate = 0.8
        self.n_rollout = 16

        # Discriminator CNN parameters
        self.filter_sizes = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20]
        self.num_filters = [100, 200, 200, 200, 200, 100, 100, 100, 100, 100, 160, 160]
        self.dropout_prob = 0.75

        # Device
        self.use_cuda = False  # Will be set based on availability

    def update_from_args(self, args):
        """Update configuration from argparse arguments."""
        for key, value in vars(args).items():
            if hasattr(self, key) and value is not None:
                setattr(self, key, value)
