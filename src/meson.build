sources = [
   'application.vala',
   'window.vala' ,
   'widgets/terminal.vala'
]

config_file = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf
)

deps = [
    dependency('gtk4'),
    dependency('libhelium-1'),
    # TODO add this as a subproject or smth, or make a vte-gtk4 package for tau. idk
    dependency('vte-2.91-gtk4')
]

add_project_arguments(['--define', 'VTE_0_68_GTK4'], language : 'vala')

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
