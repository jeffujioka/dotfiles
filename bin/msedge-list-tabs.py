# microsoft-edge --remote-debugging-port=9222
# https://www.reddit.com/r/linuxquestions/comments/9rkgq3/where_does_ubuntu_store_usermade_launchers_and/
# $HOME/.local/share/applications/msedge-jofcjnlbhnljdeapdjgodjlakohpfnjo-Profile_1.desktop
# http_proxy= python .scripts/msedge-list-tabs.py 

import argparse

from selenium import webdriver
from selenium.webdriver import EdgeOptions
from selenium.webdriver.edge.service import Service
from selenium.webdriver.common.by import By

import time

def main():
    parser = argparse.ArgumentParser(description='TODO')

    parser.add_argument('opt_search_url', type=str, help='URL domain')
    # parser.add_argument('--optional_arg', type=int, help='')

    args = parser.parse_args()

    search_url = args.opt_search_url

    print("search_url:", search_url)

    # service = Service(verbose = True, executable_path='/lhome/jfujiok/.local/bin/msedgedriver')

    options = EdgeOptions()
    options.add_experimental_option("debuggerAddress", "127.0.0.1:9222")
    # options.binary_location = "/usr/bin/microsoft-edge"
    # driver = webdriver.Edge(service=service, options=options)
    driver = webdriver.Edge(options=options)

    current_url = driver.current_url
    orig_handle = driver.current_window_handle
    found = False
    print("current URL: ", current_url, ", current_window_handle:", driver.current_window_handle)
    print("printing URLs ...")
    for handle in driver.window_handles:
        driver.switch_to.window(handle)
        # print(driver.current_url)
        # time.sleep(1)
        if search_url in driver.current_url:
            print(driver.current_url)
            found = True
            break
    if not found:
        print("not found... restoring...")
        # time. a(0.5)
        driver.switch_to.window(orig_handle)
        print(driver.current_url, ", current_window_handle: ", driver.current_window_handle, ", orig: ", orig_handle)

    driver.quit()

if __name__ == "__main__":
    main()
