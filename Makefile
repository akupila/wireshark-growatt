.PHONY: install
install: growatt.lua
	@mkdir -p ~/.local/lib/wireshark/plugins
	cp $< ~/.local/lib/wireshark/plugins
