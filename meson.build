project(
    'co.tauos.Fermion',
    ['c', 'vala'],
    version: '0.1.0',
    meson_version: '>= 0.59.0',
    default_options: [ 'warning_level=2', ],
)

application_id = 'co.tauos.Fermion'

if get_option('development')
  app_id = 'co.tauos.Fermion.Devel'
  name_suffix = ' (Development)'
else
  app_id = 'co.tauos.Fermion'
  name_suffix = ''
endif

conf = configuration_data()
conf.set_quoted('APP_ID', app_id)
conf.set_quoted('NAME_SUFFIX', name_suffix)
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('APP_SETTINGS', application_id + '.Settings')
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language:'c')

vapi_dir = join_paths(meson.project_source_root(), 'vapi')
add_project_arguments(
	['--vapidir', vapi_dir],
	language: 'vala'
)
add_project_arguments(
    '-DPCRE2_CODE_UNIT_WIDTH=0',
    language: 'c'
)

asresources = gnome.compile_resources(
	'as-resources', join_paths(meson.project_source_root(), 'data', application_id + '.gresource.xml'),
	source_dir: join_paths(meson.project_source_root(), 'data'),
	c_name: 'as'
)

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
