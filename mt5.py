"""
MetaTrader 5 Connection Module

This module provides functionality to connect to MetaTrader 5 terminal
and retrieve basic terminal information.
"""

import os
import sys
from typing import Optional

from dotenv import load_dotenv

import MetaTrader5 as mt5

# Load environment variables from .env file
load_dotenv()


def get_mt5_credentials() -> tuple[Optional[str], Optional[str], Optional[str]]:
    """
    Retrieve MT5 credentials from environment variables.

    Returns:
        tuple: (login, password, server) - Returns None for missing credentials
    """
    login = os.getenv("MT5_LOGIN")
    password = os.getenv("MT5_PASSWORD")
    server = os.getenv("MT5_SERVER")

    return login, password, server


def initialize_mt5() -> bool:
    """
    Initialize MetaTrader 5 terminal connection.

    Returns:
        bool: True if initialization successful, False otherwise
    """
    if not mt5.initialize():
        print("Failed to initialize MetaTrader 5 terminal")
        return False

    return True


def login_to_mt5(
    login: Optional[str], password: Optional[str], server: Optional[str]
) -> bool:
    """
    Login to MetaTrader 5 terminal with credentials.

    Args:
        login: MT5 login number
        password: MT5 password
        server: MT5 server name

    Returns:
        bool: True if login successful, False otherwise
    """
    if not all([login, password, server]):
        print("Warning: MT5 credentials not provided. Using current terminal session.")
        return True

    if not mt5.login(login=int(login), password=password, server=server):
        print(f"Failed to login to MT5. Error: {mt5.last_error()}")
        return False

    print(f"Successfully logged in to MT5 server: {server}")
    return True


def display_terminal_info() -> None:
    """Display MetaTrader 5 terminal information and version."""
    try:
        # Request connection status and parameters
        terminal_info = mt5.terminal_info()
        if terminal_info:
            print("Terminal Information:")
            print(terminal_info)
        else:
            print("Failed to get terminal information")

        # Get data on MetaTrader 5 version
        version_info = mt5.version()
        if version_info:
            print(f"\nMetaTrader 5 Version: {version_info}")
        else:
            print("Failed to get version information")

    except Exception as e:
        print(f"Error retrieving terminal information: {e}")


def main() -> None:
    """Main function to establish MT5 connection and display information."""
    try:
        # Get credentials
        login, password, server = get_mt5_credentials()

        # Initialize MT5
        if not initialize_mt5():
            sys.exit(1)

        # Login with credentials if provided
        if not login_to_mt5(login, password, server):
            mt5.shutdown()
            sys.exit(1)

        # Display terminal information
        display_terminal_info()

    except KeyboardInterrupt:
        print("\nProgram interrupted by user")
    except Exception as e:
        print(f"Unexpected error: {e}")
    finally:
        # Always shutdown the connection
        mt5.shutdown()
        print("MetaTrader 5 connection closed")


if __name__ == "__main__":
    main()
