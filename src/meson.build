sources = [
   'application.vala',
   'window.vala' 
]

config_file = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf
)

deps = [
    dependency('gtk4'),
    dependency('libhelium-1'),
]

gnome = import('gnome')

executable(
    meson.project_name(),
	sources,
    config_file,
	asresources,
	vala_args: '--target-glib=2.50',
	dependencies: deps,
	install: true,
)
